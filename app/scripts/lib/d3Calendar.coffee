define (require) ->
  Ember = require 'ember'
  d3 = require 'd3'

  Ember.TEMPLATES['components/d3-calendar'] = Ember.Handlebars.compile require 'text!./d3Calendar.hbs'

  (App) ->
    App.D3CalendarComponent = Ember.Component.extend
      data: undefined
      offset: undefined
      cellWidth: 100
      cellHeight: 100
      cellPadding: 10
      margin: 10

      height: (() ->
        7 * (@cellHeight + @cellPadding) + (@margin * 2)
      ).property('cellHeight', 'cellPadding', 'margin')

      width: (() ->
        7 * (@cellWidth + @cellPadding) + (@margin * 2)
      ).property('cellWidth', 'cellPadding', 'margin')

      paddedData: (() ->
        offset = @getWithDefault 'offset', 0
        data = @getWithDefault 'data', []
        pre = d3.range(0, offset).map(-> null)
        post = d3.range(0, 35 - offset - data.length).map(-> null)
        pre.concat(data).concat(post)
      ).property('data', 'offset')

      translateCell: (d, i) ->
        row = (Math.floor i / 7)
        cell = i % 7
        height = @cellHeight + @cellPadding
        width = @cellWidth + @cellPadding
        x = width * cell + @margin
        y = height * row + @margin
        "translate(#{x}, #{y})"

      translateDayLegend: (d, i) ->
        "translate(#{(@cellWidth + @cellPadding) * i + @cellWidth / 2.5}, #{@cellHeight / 1.5})"

      drawCell: (selection) -> selection

      draw: (() ->
        dayLegend = d3.select(@$('.day-legend')[0])
          .selectAll('.initial')
          .data(['S', 'M', 'T', 'W', 'T', 'F', 'S'])

        dayLegend.enter().append('text').classed('initial ', true)

        dayLegend
          .attr('transform', _.bind @translateDayLegend, @)

        dayLegend
          .text(_.identity)
          .attr('font-weight', 'bold')
          .attr('font-size', '48px')
          .attr('x', 0)
          .attr('y', 0)

        dayLegend.exit().remove()

        days = d3.select(@$('.cells')[0])
          .attr('transform', "translate(0, #{@cellHeight + @cellPadding})")
          .selectAll('.day')
          .data(@get('paddedData'), (d, i) => String i + @offset)

        days
          .enter()
          .append('g').classed('day', true)

        days
          .attr('transform', _.bind @translateCell, @)

        days
          .call(_.bind @drawCell, @)

        datetext = days.selectAll('.datetext')
          .data((d, i) => if d then [i - @offset] else [])

        datetext.enter().append('text').classed('datetext', true)

        datetext
          .text((d) -> d + 1)
          .attr('x', @cellHeight - 20)
          .attr('y', 20)
          .attr('font-size', '24px')
          .attr('font-weight', 'bold')

        datetext.exit().remove()

        days.exit().remove()
      ).on('didInsertElement').observes('data', 'offset')