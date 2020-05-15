# data-downloader-izumi-lab

## Requirements
 - ruby + gem + bundler (Recommend: https://github.com/rbenv/rbenv )
 - pixz

## Set up
At first, install pixz.

For max
```
brew install pixz
```

For linux
```
sudo apt install pixz
```
or build using https://github.com/vasi/pixz

Then,
```
./setup.sh
```

## Usage
```
ruby (/path/to/this-repository/)downloader.rb
```

## Note that
 - If you use this program for the first time, it require authorization of Google API. Please follow the leads, and log in with account under the controll of __**socsim.org**__ with access right to the team drive named `flex_full_processed`.
 - The maximum number of files in one directory (appears and be able to be downloaded in this system) is limited to 1,000. Please don't place more than 1,000 files in one directory on Google team drive.

## Author
Masanori HIRANO (https://mhirano.jp/; b2018mhirano@socsim.org)
