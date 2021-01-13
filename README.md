Main repo for the [Coinparty hackathon](https://coinparty.org/). See the project's [devpost page](https://devpost.com/software/bitpal).

Submission deadline Monday midnight.


# Installation

* Install Elixir
* Install npm + nodejs
* Install postgresql and setup a database.

  See `config/dev.exs` for settings, default is username and password: "postgres".

* Update dependencies: `mix deps.get`
* Update assets.

  In each web app:

  ```
  cd assets && npm install && node node_modules/webpack/bin/webpack.js --mode development
  ```


# How to run

## With all sites

From root: `mix phx.server`

Demo site: <http://demo.bitpal.lvh.me:4000/>  
Main site: <http://bitpal.lvh.me:4000/> or <localhost:4000>

## A single app

```
cd apps/bitpal_web
mix phx.server
```

And see console output for which endpoint to visit (the port is different per app). Something like <localhost:4010> or <localhost:4020>.


# Parts of the project

* Landing page

  Url: `bitpal.dev`  
  Apps: `bitpal` and `bitpal_web`

* Demo payment app

  Url: `demo.bitpal.dev`  
  App: `demo`

* Payment processor lib

  App: `payments`

## Planned

* Documentation

  Url: `docs.bitpal.dev`

* REST API

  Url: `api.bitpal.dev`

