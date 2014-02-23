define (require) ->
  Ember = require 'ember'
  d3 = require 'd3'

  Ember.TEMPLATES['calendar/month'] = Ember.Handlebars.compile require 'text!./calendarMonth.hbs'

  (App) ->
    App.CalendarMonthRoute = Ember.Route.extend
      model: (params) ->
        $.getJSON(wcJsonFile params)

      serialize: () ->
        @controllerFor('calendar').getProperties(['year', 'month'])

    App.CalendarMonthController = Ember.ArrayController.extend
      needs: ['calendar']
      offset: (() ->
        year = Number @get 'controllers.calendar.year'
        month = Number @get 'controllers.calendar.month'
        for [y, m, d, wd] in @get('controllers.calendar.content')
          if y is year and m is month and d is 1
            return wd
        return 0
      ).property('controllers.calendar.month', 'controllers.calendar.year')

      drawCell: (selection) ->
        sectionNest = d3.nest()
          .key((d) -> d.section)
          .key((d) -> d.subsection)

        colors = d3.scale.category20b()

        count = (d) -> if d then d3.sum d.mapProperty 'count' else d

        counts = @get('data').map(count)
        max = d3.max counts

        height = @cellHeight
        width = @cellWidth

        dayHeight = (d) -> height * d / max
        dayWidth = (d) -> width * d / max
        dayXOffset = (d) -> (width - dayWidth d) / 2
        dayYOffset = (d) -> (height - dayHeight d) / 2

        section = selection.selectAll('.section')
          .data((d) ->
            if not d then return []
            dayWC = d3.sum d.mapProperty 'count'
            dayP = dayWC / max
            nestedBySection = sectionNest.entries(Ember.makeArray d)
            data = nestedBySection
              .map(({key, values}) ->
                key: key
                values: values
                count: d3.sum _.flatten values.map ({values}) -> d3.sum values.mapProperty 'count'
              )
              .reduce(
                ({offset, sections}, {key, values, count}) ->
                  sectionP = count / dayWC
                  sectionXOffset = dayXOffset(dayWC)
                  sectionYOffset = height * dayP * offset + dayYOffset dayWC
                  sectionHeight = height * dayP * sectionP
                  sectionWidth = dayWidth(dayWC)
                  subsections = values.map(({key, values}) ->
                    key: key
                    values: values
                    count: d3.sum values.mapProperty 'count'
                  ).reduce(
                    ({offset, subsections}, subsection) ->
                      subsectionP = subsection.count / count
                      subsectionXOffset = dayXOffset(dayWC) + dayWidth(dayWC) * 0.1
                      subsectionYOffset = sectionYOffset + (sectionHeight * offset)
                      subsectionHeight = sectionHeight * subsectionP
                      subsectionWidth = dayWidth(dayWC) - dayWidth(dayWC) * 0.2
                      {offset: offset + subsectionP, subsections: subsections.concat [{key: subsection.key, subsectionXOffset, subsectionYOffset, subsectionWidth, subsectionHeight}]}
                    {offset: 0, subsections: []}
                  ).subsections
                  {offset: offset + sectionP, sections: sections.concat([{key, sectionXOffset, sectionYOffset, sectionHeight, sectionWidth, subsections}])}
                {offset: 0, sections: []}
            ).sections
            _.sortBy(data, (d) -> d.key.toLowerCase())
          )

        section.enter().append('rect').classed('section', true)

        section
          .attr('fill', ({key}) -> colors key)
          .attr('height', 0)
          .attr('width', 0)
          .attr('opacity', 0)
          .transition()
          .duration(250)
          .attr('x', ({sectionXOffset}) -> sectionXOffset)
          .attr('y', ({sectionYOffset}) -> sectionYOffset)
          .attr('height', ({sectionHeight}) -> sectionHeight)
          .attr('width', ({sectionWidth}) -> sectionWidth)
          .attr('opacity', 1)

        section.each (d) ->
          subsection = d3.select($(@).parent()[0])
            .selectAll('.subsection.%@'.fmt d.key)
            .data(d.subsections)

          subsection.enter().append('rect').classed('subsection %@'.fmt(d.key), true)

          subsection
            .attr('fill', ({key}) -> colors key)
            .attr('height', 0)
            .attr('width', 0)
            .attr('opacity', 0)
            .transition()
            .duration(250)
            .attr('x', ({subsectionXOffset}) -> subsectionXOffset)
            .attr('y', ({subsectionYOffset}) -> subsectionYOffset)
            .attr('height', ({subsectionHeight}) -> subsectionHeight)
            .attr('width', ({subsectionWidth}) -> subsectionWidth)
            .attr('opacity', 1)

          subsection.exit().remove()

        section.exit()
          .each((d) ->
            d3.select($(@).parent()[0])
              .selectAll('.subsection')
              .remove()
          )
          .remove()

        selection
