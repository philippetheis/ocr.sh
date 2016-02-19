# ocr.sh
optical character recognition project

Inputs from:
https://dr-luthardt.de/linux.htm?tip=pdfx

Requred (from poppler-utils)
sudo apt-get install pdftk
sudo apt-get install pdftoppm


Install Language:
- check installed languages: tesseract --list-langs
- Following Languages are available: https://github.com/tesseract-ocr/langdata
- sudo apt-get install tesseract-ocr-[lan] e.g.:sudo apt-get install tesseract-ocr-eng
