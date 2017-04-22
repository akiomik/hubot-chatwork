hubot-chatwork
==============

A Hubot adapter for chatwork.

[![Build Status](https://travis-ci.org/akiomik/hubot-chatwork.svg?branch=master)](https://travis-ci.org/akiomik/hubot-chatwork)
[![Dependency Status](https://gemnasium.com/akiomik/hubot-chatwork.svg)](https://gemnasium.com/akiomik/hubot-chatwork)
[![npm version](https://badge.fury.io/js/hubot-chatwork.svg)](http://badge.fury.io/js/hubot-chatwork)

## Installation

1. Install `hubot-chatwork`.
  ```sh
npm install -g yo generator-hubot
yo hubot --adapter chatwork
  ```

2. Set environment variables.
  ```sh
export HUBOT_CHATWORK_TOKEN="DEADBEEF" # see http://developer.chatwork.com/ja/authenticate.html
export HUBOT_CHATWORK_ROOMS="123,456"   # comma separated. Set 0 to read all rooms
export HUBOT_CHATWORK_API_RATE="350"   # request per hour
  ```

3. Run hubot with chatwork adapter.
  ```sh
bin/hubot -a chatwork
  ```

## License
The MIT License. See `LICENSE` file.
