define (require) ->

  App = require 'app'
  $ = require 'jquery'
  _ = require 'lodash'
  d3 = require 'd3'

  App.Issue = DS.Model.extend
    date_text: DS.attr()
    year: DS.attr 'number'
    month: DS.attr 'number'
    day: DS.attr 'number'
    document: DS.attr()

  App.IssuesIssueController = Ember.ObjectController.extend
    needs: ['sections', 'subsections']
    sectionTypeBinding: 'controllers.sections.active'
    subsectionTypeBinding: 'controllers.subsections.active'

    articles: (() ->
      sectionType = @get 'sectionType'
      subsectionType = @get 'subsectionType'
      d3.nest()
        .key((d) -> d.type)
        .entries _.flatten($.makeArray(@get('data.sections'))
          .filter((d) -> d.type is sectionType)
          .getEach('subsections')
          .map((subsection) ->
            subsection
              .filter((d) -> d.type is subsectionType)
              .map((d) -> d.articles)
          )
        )
    ).property('content', 'sectionType', 'subsectionType')