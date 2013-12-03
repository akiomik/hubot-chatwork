hubot-chatwork
==============

A Hubot adapter for chatwork.

[![Build Status](https://travis-ci.org/akiomik/hubot-chatwork.png?branch=master)](https://travis-ci.org/akiomik/hubot-chatwork)

## Installation

1. Add `hubot-chatwork` to dependencies in your hubot's `package.json`.
```
"dependencies": {
  # other packages...
  "hubot-chatwork": "0.0.1"
}
```

2. Install `hubot-chatwork`.
```sh
npm install
```

3. Set environment variables.
```sh
export HUBOT_CHATWORK_TOKEN="DEADBEEF" # see http://developer.chatwork.com/ja/authenticate.html
export HUBOT_CHATWORK_ROOM="123,456"   # comma separated
export HUBOT_CHATWORK_API_RATE="350"   # request per hour
```

4. Run hubot with chatwork adapter.
```sh
bin/hubot -a chatwork
```

## License
The MIT License. See `LICENSE` file.
