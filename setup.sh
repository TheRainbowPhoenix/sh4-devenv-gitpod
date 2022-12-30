#!/bin/sh

# check if curl is present
# if not, download curl
if [ ! -n "$(command -v curl)" ]; then
  sudo apt -y install curl
fi

if [ ! -n "$(command -v unzip)" ]; then
  sudo apt -y install unzip
fi

# wget -O http://example.com/url/to/gcc-sh4.zip

echo "TODO: compile" >> setup.log


#include <stdio.h>
int main() {
   // printf() displays the string inside quotation
   printf("Hello, World!");
   return 0;
}