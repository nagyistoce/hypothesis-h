mail = require('./vendor/jwz')

class StreamCards
  cards: null

  constructor: ->
    @cards = mail.messageContainer()

  beforeAnnotationCreated: (event, annotation) =>
    container = mail.messageContainer(annotation)
    @cards.addChild container

  annotationCreated: (event, annotation) =>
    for child in (@cards.children or []) when child.message is annotation
      child.message = null
      @cards.removeChild child
      container = mail.messageContainer(annotation)
      @cards.addChild container
      break

  annotationDeleted: (event, annotation) =>
    for child in (@cards.children or []) when child.message is annotation
      child.message = null
      @cards.removeChild child
      break

  annotationsLoaded: (event, annotations) =>
    for annotation in annotations
      container = mail.messageContainer(annotation)
      @cards.addChild container


class StreamSearchController
  this.inject = [
    '$scope', '$rootScope', '$routeParams',
    'auth', 'queryparser', 'searchfilter', 'store',
    'streamer', 'streamfilter', 'annotationMapper'
  ]
  constructor: (
     $scope,   $rootScope,   $routeParams
     auth,   queryparser,   searchfilter,   store,
     streamer,   streamfilter, annotationMapper
  ) ->
    # Initialize cards
    cards = new StreamCards()

    $rootScope.$on('beforeAnnotationCreated', cards.beforeAnnotationCreated)
    $rootScope.$on('annotationCreated', cards.annotationCreated)
    $rootScope.$on('annotationDeleted', cards.annotationDeleted)
    $rootScope.$on('annotationsLoaded', cards.annotationsLoaded)

    $scope.$watch (->cards.cards), (cards) ->
      $scope.threadRoot = cards

    # Initialize the base filter
    streamfilter
      .resetFilter()
      .setMatchPolicyIncludeAll()

    # Apply query clauses
    $scope.search.query = $routeParams.q
    terms = searchfilter.generateFacetedFilter $scope.search.query
    queryparser.populateFilter streamfilter, terms
    streamer.send({filter: streamfilter.getFilter()})

    # Perform the search
    searchParams = searchfilter.toObject $scope.search.query
    query = angular.extend limit: 10, searchParams
    store.SearchResource.get query, ({rows}) ->
      annotationMapper.loadAnnotations(rows)

    $scope.isEmbedded = false
    $scope.isStream = true

    $scope.sort.name = 'Newest'

    $scope.shouldShowThread = (container) -> true

    $scope.$on '$destroy', ->
      $scope.search.query = ''

angular.module('h')
.controller('StreamSearchController', StreamSearchController)
