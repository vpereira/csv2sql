# Csv2sql - Comma separated values files to sql conversion
#
# Copyright (c) 2007, London
# Mirek Rusin <ruby@mirekrusin.com>
#
# Licenced under GNU LGPL, http://www.gnu.org/licenses/lgpl.html
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
# 
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
# 
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA

#
# UPDATE 
#
# ruby gem updated to use rspec and ruby 1.9.x
require 'csv'
require 'pathname'

# Example:
# 
#   puts Csv2sql.new("account_balances.csv").to_updates([nil, 'balance'], :table => 'accounts')
#
class Csv2sql
  
  VERSION = '0.3.2'
  
  @@defaults = {
    :before     => "",   # can be changed to "start transaction;\n"
    :after      => ";\n" # can be changes to "commit;\n"
  }
  
  def self.default_value_filter(v, i=nil, j=nil)
    return 'null' if v.to_s == ''
    return v.to_s if v.is_a? Float or v.is_a? Fixnum
    v.gsub!(/\\/, '\\\\')
    v.gsub!(/"/, '\\"')
    "\"#{v}\""
  end
  
  def initialize(filename)
    @filename = filename
  end

  # Sql inserts
  #
  # Please note that you can set table name with values :table => 'my_table(id, col1, col2...)'
  # to make inserts into specific columns only.
  #
  # Optional named args:
  #   :ignore - true/false, if true uses INSERT IGNORE ...
  #   :bulk   - if true, bulk insert (see cluster size in your sql server to make big bulks to avoid server gone away!)
  #   :table  - default based on filename
  #   :before - default to blank 
  #   :after  - default to ;
  #   ...see Csv2sql#to_any for the rest
  #
  def to_inserts(args={})
    args[:table] ||= Pathname.new(@filename).basename.to_s.downcase.gsub(/\W/, '_')
    args[:before] ||= @@defaults[:before]
    args[:after]  ||= @@defaults[:after]
    insert_sql = args[:ignore] ? 'insert ignore' : 'insert'
    if args[:bulk]
      args[:before]       += "#{insert_sql} into #{args[:table]} values"
      args[:values_glue] ||= ", "
      args[:row_format]  ||= " (%s)"
      args[:row_glue]    ||= ",\n"
    else
      args[:before]      ||= ""
      args[:values_glue] ||= ", "
      args[:row_format]  ||= "#{insert_sql} into #{args[:table]} values(%s)"
      args[:row_glue]    ||= ";\n"
    end
    to_any args
  end
  
  # Sql updates from csv file (useful when one of the columns is a PK)
  #
  #   set_columns - ie. [nil, 'first_name', 'last_name'] will ignore first column (PK probably) and set first_name and last_name attributes
  #
  # Optional args:
  #   :pk - default to first (index 0) column in csv file with 'id' name, a pair: [0, 'id']
  #
  def to_updates(set_columns, args={})
    args[:pk]          ||= [0, 'id']
    args[:table]       ||= Pathname.new(@filename).basename.to_s.downcase.gsub(/\W/, '_')
    args[:before]      ||= @@defaults[:before]
    args[:after]       ||= @@defaults[:after]
    args[:values_glue] ||= ", "
    args[:row_format]  ||= lambda do |values|
      r = []
      set_columns.each_with_index { |set_column, i| r << "#{set_column} = #{values[i]}" if set_column }
      "update #{args[:table]} set #{r.join(', ')} where #{args[:pk][1]} = #{values[args[:pk][0]]}"
    end
    args[:row_glue]    ||= ";\n"
    to_any args
  end
  
  # When :row_format is proc, values_glue is ignored
  #   :before 
  #   :values_glue
  #   :row_format
  #   :row_glue
  #   :after
  #   :when_empty
  #
  def to_any(args={})
    args[:when_empty]  ||= ""
    args[:values_glue] ||= ", "
    args[:row_format]  ||= "%s"
    args[:row_glue]    ||= "\n"
    r = []
    case args[:row_format].class.to_s
      when 'String'
        parse(args) do |values|
          r << sprintf(args[:row_format], values.join(args[:values_glue]))
        end
        
      when 'Proc'
        parse(args) do |values|
          r << args[:row_format].call(values) # LOOK OUT: args[:values_glue] ignored
        end
    end
    if r.size > 0
      r = r.join args[:row_glue]
      r = args[:before] + r if args[:before]
      r = r + args[:after] if args[:after]
      r
    else
      args[:when_empty]
    end
  end
  
  # Parse file
  #
  # args[:values_filter] - proc, called with (values, line_number)
  # args[:value_filter] - proc, called with values, line_number, column_number
  #
  def parse(args={})
    args[:value_filter] ||= Csv2sql.method :default_value_filter
    i = 0
    CSV.foreach(@filename) do |row|
      values = row
      #values_filter is for whole row
      #value_filter is for single value
      values = args[:values_filter].call(row, i) if args[:values_filter]
      if values
        if args[:value_filter]
          j = -1
          values = row.map do |value|
            j += 1
            args[:value_filter].call(value,i,j)
          end
        end
        yield values if values
      end
      i += 1
    end
  end

end
