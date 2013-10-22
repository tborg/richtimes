define (require) ->

  App = require 'app'
  DS = require 'emberData'

  App.ContentType = DS.Model

  App.Date = DS.Model.extend
    date_text: DS.attr()
    year: DS.attr 'number'
    month: DS.attr 'number'
    day: DS.attr 'number'
    sections: DS.attr()  # array of section ids; don't sideload.

  App.Section = DS.Model.extend
    articles: DS.attr()

  App.Article = DS.Model.extend
    type: DS.attr 'string'
    content: DS.attr 'string'