# Southy

### Automatic checkin for Southwest flights

Southy is a command line app that will check you in to your Southwest flights
  exactly 24 hours in advance, and email you your boarding passes.

## Installation

Important: if you want emails to be sent with boarding passes attached as a PDF,
  you must first install wkhtmltopdf.  Good instructions for OS X and various
  Linux distros are here:
  
https://github.com/jdpace/PDFKit/wiki/Installing-WKHTMLTOPDF

I strongly suggest you download the pre-compiled binaries for both OS X and Ubuntu.

After that is installed, you just install Southy as a gem:

% gem install southy

## Usage

To see how to use Southy, just run it with no arguments:

% southy
