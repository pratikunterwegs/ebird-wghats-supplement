#' ---
#' editor_options: 
#'   chunk_output_type: console
#' ---
#' 
#' # Landcover classification
#' 
#' This script was used to classify a 2019 Sentinel composite image across the Nilgiris and the Anamalais into seven distinct land cover types. The same code can be viewed on GEE here: https://code.earthengine.google.com/ec69fc4ffad32a532b25202009243d42. 
#' We use ground truthed points from a previous study [@arasumani2019].
#' 
## // Data: Groundtruthed points from Arasumani et al 2019

## 
## // Function to obtain a Cloud-Free Image //

## 
## /**

##  * Function to mask clouds using the Sentinel-2 QA band

##  * @param {ee.Image} image Sentinel-2 image

##  * @return {ee.Image} cloud masked Sentinel-2 image

##  */

## 

## function maskS2clouds(image) {

##   var qa = image.select('QA60');

## 
##   // Bits 10 and 11 are clouds and cirrus, respectively.

##   var cloudBitMask = 1 << 10;

##   var cirrusBitMask = 1 << 11;

## 
##   // Both flags should be set to zero, indicating clear conditions.

##   var mask = qa.bitwiseAnd(cloudBitMask).eq(0)

##       .and(qa.bitwiseAnd(cirrusBitMask).eq(0));

## 
##   return image.updateMask(mask).divide(10000);

## }

## 
## // Importing shapefile needed for classification

## var clipper = function(image){

##   return image.clip(WG_Buffer);

## };

## 
## 
## // Import raw Sentinel scenes and clip them over your study area

## var filtered = sentinel.filterDate('2018-01-01','2018-12-01').map(clipper);

## 
## // Load Sentinel-2 TOA reflectance data.

## // Pre-filter to get less cloudy granules.

## 
## var dataset = filtered.filter(ee.Filter.lt('CLOUDY_PIXEL_PERCENTAGE', 20))

##                   .map(maskS2clouds);

## var scene = dataset.reduce(ee.Reducer.median());

## 
## Map.addLayer(WG_Buffer, {}, 'Buffer Outline for Nil/Ana/Pal');

## // Map.addLayer(scene,{},'Image for Classification');

## // Map.addLayer(WG, {},'Outline for Nilgiris/Anaimalais/Palanis');

## 
## 
## // Step 2: Creating training data manually

## // Added a new shapefile field manually in ArcMap so that GEE can take a float field for classification

## // Field: landcover

## // Values: agriculture (1), forest (2), grassland (3), plantation (4), settlements (5), tea (6), waterbodies (7)

## // Note - Arasu has classified plantation as Acacia, Pine et al sub classes (for future analysis)

## 
## // Merging the featureCollections to obtain a single featureCollection

## 
## var trainingFeatures = agriculture.merge(forests).merge(forests2).merge(grasslands).merge(grasslands2)

##                                .merge(settlements).merge(plantations)

##                             .merge(waterbodies).merge(tea).merge(tea2).merge(tea3).merge(forests3);

## 
## // // Specify the bands of the sentinel image to be used as predictors (p)

## var predictionBands = ['B2_median','B3_median','B4_median','B8_median'];

## 
## 
## // // Now a random forest is a collection of random trees. It's predictions are used to compute an

## // // average (regression) or vote on a label (classification)

## 
## var sample = scene.select(predictionBands)

##                       .sampleRegions({

##                         collection: trainingFeatures,

##                         properties : ['landcover'],

##                         scale: 10

##                               });

## 
## // Let's run a classifier for randomForest

## var classifier = ee.Classifier.randomForest(10).train({

##                             features: sample,

##                             classProperty: 'landcover',

##                             inputProperties: predictionBands

## });

## 
## 
## var classified = scene.select(predictionBands).classify(classifier);

## Map.addLayer(classified, {min:1, max:7,palette:[

##   'be4fc4', // agriculture, violetish

##   '04a310', // forests, lighter green

##   'cbb315', // grasslands, yellowish

##   'c17111', // plantations, brownish

##   'b0a69d', // settlements, grayish

##   '025a05', // tea, dark greenish

##   '2035df', // waterbodies, royal blue

##   ]}, 'classified');

## 
## // Partitioning training data to run an accuracy assessment

## // Adding a randomColumn of values ranging from 0 to 1

## var trainingTesting = sample.randomColumn();

## 
## var trainingSet = trainingTesting.filter(ee.Filter.lt('random',0.8));

## var testingSet = trainingTesting.filter(ee.Filter.gte('random',0.2));

## 
## // Now run the classifier only with the trainingSet

## var trained = ee.Classifier.randomForest(10).train({

##   features: trainingSet,

##   classProperty: 'landcover',

##   inputProperties: predictionBands

## });

## 
## // Now classify the testData and obtain a Confusion matrix

## var confusionMatrix = ee.ConfusionMatrix(testingSet.classify(trained)

##                                                   .errorMatrix({

##                                                     actual: 'landcover',

##                                                     predicted: 'classification'

##                                                   }));

## 
## // Now print the ConfusionMatrix and expand the object to inspect the matrix()

## // The entries represent the number of pixels and the items on the diagonal represent

## // correct classification. Items off the diagonal are misclassifications, where class in row i

## // is classified as column j

## 
## // One can also obtain basic descriptive statistics from the confusionMatrix

## // Note this won't work as the number of pixels is too high (Export as .csv to obtain result)

## 
## // print('Confusion matrix:', confusionMatrix);

## // print('Overall Accuracy:', confusionMatrix.accuracy());

## // print('Producers Accuracy:', confusionMatrix.producersAccuracy());

## // print('Consumers Accuracy:', confusionMatrix.consumersAccuracy());

## 
## // Since printing the above is gives you a computation timed out error

## var exportconfusionMatrix = ee.Feature(null, {matrix: confusionMatrix.array()});

## var exportAccuracy = ee.Feature(null, {matrix: confusionMatrix.accuracy()});

## 
## Export.table.toDrive({

##   collection: ee.FeatureCollection(exportconfusionMatrix),

##   description: 'confusionMatrix',

##   fileFormat: 'CSV'

## });

## 
## Export.table.toDrive({

##   collection: ee.FeatureCollection(exportAccuracy),

##   description: 'Accuracy',

##   fileFormat: 'CSV'

## });

## 
## // Below code suggests that the current projection system is WGS84

## // print(classified.projection());

## 
## // To project it to UTM

## var reprojected = classified.reproject('EPSG:32643',null,10);

## 
## // Export classified image

## Export.image.toDrive({

##   image: classified,

##   description: 'Classified Image',

##   scale: 10,

##   region: WG_Buffer,      //.geometry().bounds(),

##   fileFormat: 'GeoTIFF',

##   formatOptions: {

##     cloudOptimized: true

##   },

##   maxPixels: 618539476

## });

## 
## // Export projected image

## Export.image.toDrive({

##   image: reprojected,

##   description: 'Reprojected Image',

##   scale: 10,

##   region: WG_Buffer,         //.geometry().bounds(),

##   fileFormat: 'GeoTIFF',

##   formatOptions: {

##     cloudOptimized: true

##   },

##   maxPixels: 618539476

## });

## 
#' 
