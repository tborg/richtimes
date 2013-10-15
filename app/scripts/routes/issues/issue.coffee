define (require) ->

  App = require 'app'
  $ = require 'jquery'
  d3 = require 'd3'

  App.Issue = DS.Model.extend
    date_text: DS.attr()
    year: DS.attr 'number'
    month: DS.attr 'number'
    day: DS.attr 'number'
    document: DS.attr()


  # App.IssuesRoute = Ember.Route.extend