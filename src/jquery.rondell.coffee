###!
  jQuery rondell plugin
  @name jquery.rondell.js
  @author Sebastian Helzle (sebastian@helzle.net or @sebobo)
  @version 0.8.1
  @date 11/02/2011
  @category jQuery plugin
  @copyright (c) 2009-2011 Sebastian Helzle (www.sebastianhelzle.net)
  @license Licensed under the MIT (http://www.opensource.org/licenses/mit-license.php) license.
###

(($) ->
  # Global rondell stuff
  $.rondell =
    version: '0.8.1'
    name: 'rondell'
    defaults:
      resizeableClass: 'resizeable'
      smallClass: 'itemSmall'
      hiddenClass: 'itemHidden'
      itemCount: 0 # Number of rondell items in a rondell
      currentLayer: 1 # Active layer number
      container: null
      controlsContainer: null
      radius: # Radius if the rondell uses a circle function
        x: 300 
        y: 300  
      center: # Center where the focused element is displayed
        left: 400 
        top: 350
      size: # Defaults to center * 2
        width: null
        height: null
      visibleItems: 'auto' # How many items should be visible in each direction
      scaling: 2 # Size of focused element
      opacityMin: 0.05 # Min opacity before elements are set to display: none
      fadeTime: 300
      zIndex: 1000 # All elements of the rondell will use this z-index and add their depth to it
      itemProperties: # Default properties for each item
        delay: 100
        cssClass: 'rondellItem'
        size: 
          width: 150
          height: 150
        sizeFocused: 
          width: 0
          height: 0
        topMargin: 20 
      repeating: true # Rondell will go forever
      autoRotation: # If the cursor leaves the rondell continue spinning
        enabled: false
        paused: false
        timer: -1
        direction: 0
        once: false
        delay: 5000
      controls: # Buttons to control the rondell
        enabled: true
        fadeTime: 400
        margin: 
          x: 20
          y: 20
      strings: # String for the controls 
        prev: 'prev'
        next: 'next'
      funcEase: 'easeInOutQuad' # Easing function name for the movement of items
  
  # Add default easing function to jQuery if missing
  unless $.easing.easeInOutQuad        
    $.easing.easeInOutQuad = (x, t, b, c, d) ->
      if ((t/=d/2) < 1) then c/2*t*t + b else -c/2 * ((--t)*(t-2) - 1) + b
   
  # Rondell class   
  class Rondell
    @rondellCount: 0
    @activeRondell: null # Stores the last activated rondell for keyboard interaction
    
    constructor: (options) ->
      @id = Rondell.rondellCount++
      @items = [] # Holds the items
      
      # Update rondell properties with new options
      $.extend(true, @, $.rondell.defaults, options or {})
    
    # Animation functions, can be different for each rondell
    funcLeft: (layerDiff, rondell) ->
      rondell.center.left - rondell.itemProperties.size.width / 2.0 + Math.sin(layerDiff) * rondell.radius.x
    funcTop: (layerDiff, rondell) ->
      rondell.center.top - rondell.itemProperties.size.height / 2.0 + Math.cos(layerDiff) * rondell.radius.y
    funcDiff: (layerDiff, rondell) ->
      Math.pow(Math.abs(layerDiff) / rondell.itemCount, 0.5) * Math.PI
    funcOpacity: (layerDist, rondell) ->
      if rondell.visibleItems > 1 then Math.max(0, 1.0 - Math.pow(layerDist / rondell.visibleItems, 2)) else 0
    
    showCaption: (layerNum) => 
      # Restore automatic height and show caption
      $('.rondellCaption.overlay', @_getItem(layerNum).object)
      .css(
        height: 'auto'
        overflow: 'auto'
      ).stop(true).fadeTo(300, 1)
      
    hideCaption: (layerNum) =>
      # Fix height before hiding the caption to avoid jumping text when the item changes its size
      caption = $('.rondellCaption.overlay:visible', @_getItem(layerNum).object) 
      caption.css(
        height: caption.height()
        overflow: 'hidden'
      ).stop(true).fadeTo(200, 0)
      
    _getItem: (layerNum) =>
      @items[layerNum - 1]
      
    _initItem: (layerNum, item) =>
      @items[layerNum - 1] = item
      
      # Wrap other content as overlay caption
      captionContent = item.icon?.siblings()
      if not (captionContent?.length or item.icon) and item.object.children().length
        captionContent = item.object.children()
      if not captionContent.length and item.icon?.attr('title')
        captionContent = $("<p>#{item.icon.attr('title')}</p>")
        item.object.append(captionContent)

      if captionContent.length
        captionContainer = $('<div class="rondellCaption"></div>')
        captionContainer.addClass('overlay') if item.icon
        captionContent.wrapAll(captionContainer)
          
      # Init click events
      item.object
      .addClass("new #{@itemProperties.cssClass}")
      .css('opacity', 0)
      .bind('mouseover mouseout click', (e) =>
        switch e.type
          when 'mouseover'
            item.object.addClass('rondellItemHovered') if item.object.is(':visible') and not item.hidden
          when 'mouseout'
            item.object.removeClass('rondellItemHovered')
          when 'click'
            if item.object.is(':visible') and not (@currentLayer is layerNum or item.hidden)
              @shiftTo(layerNum)
              e.preventDefault()
      )
      
    _start: =>
      # Set visibleItems if set to auto
      @currentLayer = Math.round(@itemCount / 2)
      @visibleItems = Math.max(2, Math.round(@itemCount / 4)) if @visibleItems is 'auto'
      
      # Create controls
      controls = @controls
      if controls.enabled
        @controlsContainer = $("<div class=\"rondellControls\"></div>")
        .append($('<a href="#"/>').addClass('rondellShiftLeft').text(@strings.prev).click(@shiftLeft))
        .append($('<a href="#/"/>').addClass('rondellShiftRight').text(@strings.next).click(@shiftRight))
        .css(
          "padding-left": controls.margin.x
          "padding-right": controls.margin.x
          left: 0
          right: 0
          top: controls.margin.y
          "z-index": @zIndex + @itemCount + 2
        )
        
        # Attach controlsto container
        @container.append(@controlsContainer)
        
      # Attach keydown event to document
      $(document).keydown(@keyDown)
      
      # add hover function to container
      @container.removeClass('initializing').bind('mouseover mouseout', @_hover)
      
      # Move items to starting positions
      @shiftTo(@currentLayer)
      
    _hover: (e) =>      
      # Show or hide controls if they exist
      $('a', @controlsContainer).stop().fadeTo(@controls.fadeTime, if e.type is 'mouseover' then 1 else 0) if @controlsContainer
      
      # Start or stop auto rotation if enabled
      paused = @autoRotation.paused
      if e.type is 'mouseover'
        Rondell.activeRondell = @.id
        @hovering = true
        unless paused
          @autoRotation.paused = true
          @showCaption(@currentLayer)
      else
        @hovering = false
        if paused and not @autoRotation.once
          @autoRotation.paused = false
          @_autoShift()
        @hideCaption(@currentLayer)
      
    layerFadeIn: (layerNum) =>
      item = @_getItem(layerNum)
      item.small = false
      itemFocusedWidth = item.sizeFocused.width
      itemFocusedHeight = item.sizeFocused.height
      
      # Move item to center position and fade in
      item.object.stop(true).show(0)
      .animate(
          width: itemFocusedWidth
          height: itemFocusedHeight
          left: @center.left - itemFocusedWidth / 2
          top: @center.top - itemFocusedHeight / 2
          opacity: 1
        , @fadeTime, @funcEase, =>
          @_autoShift()
          @showCaption(layerNum) if @hovering
      )
      .css('z-index', @zIndex + @itemCount)
      .addClass('rondellItemFocused')
      
      if item.icon and not item.resizeable
        margin = (@itemProperties.size.height - item.icon.height()) / 2
        item.icon.stop(true).animate(
            marginTop: margin
            marginBottom: margin
          , @fadeTime)
          
    layerFadeOut: (layerNum) =>
      item = @_getItem(layerNum)
      
      layerDist = Math.abs(layerNum - @currentLayer)
      layerPos = layerNum
      
      # Find new layer position
      if layerDist > @visibleItems and @repeating
        if @currentLayer + @visibleItems > @itemCount
          layerPos += @itemCount
        else if @currentLayer - @visibleItems <= @itemCount
          layerPos -= @itemCount
        layerDist = Math.abs(layerPos - @currentLayer)

      # Get the absolute layer number difference
      layerDiff = @funcDiff(layerPos - @currentLayer, @)
      layerDiff *= -1 if layerPos < @currentLayer
      
      newX = @funcLeft(layerDiff, @) + (@itemProperties.size.width - item.sizeSmall.width) / 2
      newY = @funcTop(layerDiff, @) + (@itemProperties.size.height - item.sizeSmall.height) / 2
      newZ = @zIndex + (if layerDiff < 0 then layerPos else -layerPos)
      fadeTime = @fadeTime + @itemProperties.delay * layerDist
        
      # Is item visible
      if layerDist <= @visibleItems or item.object.hasClass('new')
        @hideCaption(layerNum)
        
        newOpacity = @funcOpacity(layerDist, @)
        item.object.show() if newOpacity >= @opacityMin
        
        item.object.removeClass('new rondellItemFocused').stop(true)
        .css('z-index', newZ)
        .animate(
            width:   item.sizeSmall.width
            height:  item.sizeSmall.height
            left:    newX
            top:     newY
            opacity: newOpacity 
          , fadeTime, @funcEase, =>
            if item.object.css('opacity') < @opacityMin then item.object.hide() else item.object.show()
        )
        
        item.hidden = false
        unless item.small
          item.small = true
          if item.icon and not item.resizeable
            margin = (@itemProperties.size.height - item.icon.height()) / 2
            item.icon.stop(true).animate(
                marginTop: margin
                marginBottom: margin
              , fadeTime
            )
      else if item.hidden
        # Update position even if out of view to 
        item.object.css(
          left: newX
          top: newY
          'z-index': newZ
        )
      else
        # Hide items which are moved out of view
        item.hidden = true
        item.object.stop(true)
        .css('z-index', newZ)
        .animate(
            left: newX
            top: newY
            opacity: 0
          , fadeTime, @funcEase, =>
          @hideCaption(layerNum)
        )

    shiftTo: (layerNum) =>
      itemCount = @itemCount
      
      if @repeating 
        # Update current layer
        if layerNum < 1 
          layerNum = itemCount
        else if layerNum > itemCount 
          layerNum = 1
      
      if layerNum > 0 and layerNum <= itemCount
        @currentLayer = currentLayer = layerNum
        
        # Hide all layers except the current layer
        @layerFadeOut(i) for i in [1..itemCount] when i isnt currentLayer
        @layerFadeIn(currentLayer)
         
    shiftLeft: (e) => 
      e.preventDefault() if e
      @shiftTo(@currentLayer - 1) 
        
    shiftRight: (e) => 
      e.preventDefault() if e
      @shiftTo(@currentLayer + 1) 
        
    _autoShift: =>
      autoRotation = @autoRotation
      if @isActive() and autoRotation.enabled and autoRotation.timer < 0
        # store timer id
        autoRotation.timer = window.setTimeout( =>
            @autoRotation.timer = -1
            if @isActive() and not autoRotation.paused
              if autoRotation.direction then @shiftRight() else @shiftLeft()
          , autoRotation.delay
        )
        
    isActive: ->
      true
    
    keyDown: (e) =>
      if @isActive() and Rondell.activeRondell is @.id
        # Clear current rotation timer on user interaction
        if @autoRotation.timer >= 0
          window.clearTimeout(@autoRotation.timer) 
          @autoRotation.timer = -1
          
        switch e.which
          # arrow left
          when 37 then @shiftLeft(e)
          # arrow right 
          when 39 then @shiftRight(e) 
  
  $.fn.rondell = (options) ->
    # Create new rondell instance
    rondell = new Rondell(options)
    
    itemProperties = rondell.itemProperties
    itemWidth = itemProperties.size.width
    itemHeight = itemProperties.size.height
    scaling = rondell.scaling
    center = rondell.center
    radius = rondell.radius
      
    containerWidth = rondell.size.width |= center.left * 2
    containerHeight = rondell.size.height |= center.top * 2
    
    focusedWidth = itemProperties.sizeFocused.width or itemWidth * scaling
    focusedHeight = itemProperties.sizeFocused.height or itemHeight * scaling
    
    maxItems = @length
      
    # Wrap elements in new container
    @wrapAll($('<div class="rondellContainer initializing"></div>'))
      
    container = rondell.container = @parent().css
      width: containerWidth
      height: containerHeight
          
    # Wrap elements and setup each item
    @each ->
      obj = $(@)
      objIcon = $('img:first', obj)
      
      if objIcon.length
        # Wait for the image to load and init icon based item
        objIcon.load( ->
          icon = $(@)
          isResizeable = icon.hasClass(rondell.resizeableClass)
          layerNum = rondell.itemCount += 1
          
          # create size vars for the small and focused size
          foWidth = smWidth = icon.width()
          foHeight = smHeight = icon.height()
        
          if isResizeable
            if smWidth >= smHeight
              # compute smaller side length
              smHeight *= itemWidth / smWidth
              foHeight *= focusedWidth / foWidth
              # compute full size length
              smWidth = itemWidth
              foWidth = focusedWidth
            else
              # compute smaller side length
              smWidth *= itemHeight / smHeight
              foWidth *= focusedHeight / foHeight
              # compute full size length
              smHeight = itemHeight
              foHeight = focusedHeight
          else
            # scale to given sizes
            smWidth = itemWidth
            smHeight = itemHeight
            foWidth = focusedWidth
            foHeight = focusedHeight
            
          # Set vars in item array
          rondell._initItem(layerNum, 
            object: obj 
            icon: icon
            small: false 
            hidden: false
            resizeable: isResizeable
            sizeSmall: 
              width: smWidth
              height: smHeight
            sizeFocused: 
              width: foWidth
              height: foHeight
          )
              
          rondell._start() if rondell.itemCount is maxItems
        )
      else
        layerNum = rondell.itemCount += 1
        
        # Init non-icon item
        rondell._initItem(layerNum, 
          object: obj 
          icon: null
          small: false 
          hidden: false
          resizeable: false
          sizeSmall: 
            width: itemWidth
            height: itemHeight
          sizeFocused: 
            width: focusedWidth
            height: focusedHeight
        )
            
        rondell._start() if rondell.items.length is maxItems
      
    $(@)
    
)(jQuery) 