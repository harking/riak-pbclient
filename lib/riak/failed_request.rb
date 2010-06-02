# Copyright 2010 Sean Cribbs, Sonian Inc., and Basho Technologies, Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
require 'riak'

module Riak
  # Exception raised when the expected response code from Riak
  # fails to match the actual response code.
  class FailedRequest < StandardError
    include Riak::Util::Translation

    attr_reader :expected
    attr_reader :actual
    attr_reader :output
    attr_reader :message

    def initialize(expected=nil, actual=nil, output=nil, message=nil)
      @expected = expected
      @actual   = actual
      @output   = output
      @message  = message || "failed_request"
      super t(@message, :expected => @expected, :actual => @actual, :output => @output.inspect)
    end
  end
end