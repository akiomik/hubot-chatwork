hubot-chatwork
==============

A Hubot adapter for chatwork.

[![Build Status](https://travis-ci.org/akiomik/hubot-chatwork.png?branch=master)](https://travis-ci.org/akiomik/hubot-chatwork)
[![Coverage Status](https://coveralls.io/repos/akiomik/hubot-chatwork/badge.png?branch=master)](https://coveralls.io/r/akiomik/hubot-chatwork?branch=master)
[![Dependency Status](https://gemnasium.com/akiomik/hubot-chatwork.png)](https://gemnasium.com/akiomik/hubot-chatwork)
[![NPM version](https://badge.fury.io/js/hubot-chatwork.png)](http://badge.fury.io/js/hubot-chatwork)

## Installation

1. Add `hubot-chatwork` to dependencies in your hubot's `package.json`.
```javascript
"dependencies": {
      // other packages...
      "hubot-chatwork": "0.0.3"
}
```

2. Install `hubot-chatwork`.
```sh
npm install
```

3. Set environment variables.
```sh
export HUBOT_CHATWORK_TOKEN="DEADBEEF" # see http://developer.chatwork.com/ja/authenticate.html
export HUBOT_CHATWORK_ROOMS="123,456"   # comma separated
export HUBOT_CHATWORK_API_RATE="350"   # request per hour
```

4. Run hubot with chatwork adapter.
```sh
bin/hubot -a chatwork
```

## License
The MIT License. See `LICENSE` file.
