#
# Copyright (C) 2012 Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

# This is a utility wrapper class for making custom paginated collections that
# are compatible with WillPaginate (so they can be used with Api.paginate,
# mainly).
#
# For example:
#   collection = PaginatedCollection.build do |pager|
#     pager.replace(some_custom_query(pager.current_page, pager.per_page))
#   end
#   Api.paginate(collection)
#
# The pager object passed into the block is a PaginatedCollection::Collection,
# which is a subclass of Array with the WillPaginate attributes added.
# This is similar to a WillPaginate::Collection, the primary differences
# being the way it is initialized, greater flexibility in specifying next/total
# pages, and it allows non-integer page ids.
#
# You can set pager.total_entries if you know a total count, or you can set
# pager.next_page to the id of the next page if you know there's another page,
# but don't have a total count.
#
# You can also use PaginatedCollection with an underlying collection such as an
# AR scope, if you want to do custom mapping of that scope result.
#
# For example:
#   collection = PaginatedCollection.build do |pager|
#     students = @course.students.paginate(:page => pager.current_page, :per_page => pager.per_page)
#     students.map! { |s| s = s.to_json; s['other_attr'] = some_method(s); s }
#   end
#   students = Api.paginate(collection)
#
# Note that the block needs to edit the AR collection in-place, because it's a
# subclass of Array with paging information, rather than just a raw array.
module PaginatedCollection
  def self.build(&block)
    raise(ArgumentError, "block required") unless block
    Proxy.new(block)
  end

  class Collection < Array
    # these are set before the collection is populated
    attr_accessor :current_page, :per_page
    # these can optionally be set while populating the collection
    attr_accessor :next_page, :previous_page, :first_page, :last_page, :total_entries

    def total_pages
      if total_entries
        (total_entries / per_page.to_f).ceil
      else
        nil
      end
    end
  end

  class Proxy
    attr_accessor :block

    def initialize(block)
      @block = block
    end

    def paginate(options = {})
      raise(ArgumentError, "per_page required") unless options[:per_page] && options[:per_page] > 0

      pager = PaginatedCollection::Collection.new
      pager.current_page = options[:page]
      pager.per_page = options[:per_page]
      pager.total_entries = options[:total_entries]

      pager = block.call(pager)
      if !pager.respond_to?(:current_page)
        raise(ArgumentError, "The PaginatedCollection block needs to return a WillPaginate-style object")
      end

      return pager
    end
  end
end
