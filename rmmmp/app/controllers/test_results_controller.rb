class TestResultsController < ApplicationController
  def index
    threshold = params[:threshold]
    drugs     = params[:drug]
    relation  = params[:relation]

    # TODO
    # call Randys method that returns a test_results data structure
    #

    @results = [] #test_results data structure
  end
end