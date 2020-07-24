#!/bin/bash
Rscript --slave -e 'bookdown::render_book("index.rmd")'
Rscript --slave -e 'bookdown::render_book("index.rmd", output_format = "bookdown::pdf_book")'
