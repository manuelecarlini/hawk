#======================================================================
#                        HA Web Konsole (Hawk)
# --------------------------------------------------------------------
#            A web-based GUI for managing and monitoring the
#          Pacemaker High-Availability cluster resource manager
#
# Copyright (c) 2011 Novell Inc., Tim Serong <tserong@novell.com>
#                        All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it would be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# Further, this software is distributed without any warranty that it is
# free of the rightful claim of any third person regarding infringement
# or the like.  Any license provided herein, whether implied or
# otherwise, applies only to this software file.  Patent licenses, if
# any, provided herein do not apply to combinations of this program with
# other software, or any other product whatsoever.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write the Free Software Foundation,
# Inc., 59 Temple Place - Suite 330, Boston MA 02111-1307, USA.
#
#======================================================================

class Location < Constraint
  @attributes = :rules, :rsc
  attr_accessor *@attributes
  
  def initialize(attributes = nil)
    @rules  = []
    @rsc    = ''
    super
  end

  def validate
    # TODO(must): implement.
    error "RULES NOT YET IMPLEMENTED" unless simple?

    error _('Constraint is too complex - it contains nested rules') if too_complex?

    error _('No rules specified') if @rules.empty?

    @rsc.strip!
    error _("No resource specified") if @rsc.empty?

    @rules.each do |rule|
      rule[:score].strip!
      unless ['mandatory', 'advisory', 'inf', '-inf', 'infinity', '-infinity'].include? rule[:score].downcase
        unless rule[:score].match(/^-?[0-9]+$/)
          error _('Invalid score "%{score}"') % { :score => rule[:score] }
        end
      end
      error _('No expressions specified') if rule[:expressions].empty?
    end
  end

  def create
    if CibObject.exists?(id)
      error _('The ID "%{id}" is already in use') % { :id => @id }
      return false
    end

    cmd = shell_syntax
    cmd += "\ncommit\n"

    result = Invoker.instance.crm_configure cmd
    unless result == true
      error _('Unable to create constraint: %{msg}') % { :msg => result }
      return false
    end

    true
  end
  
  def update
    unless CibObject.exists?(id, 'rsc_location')
      error _('Constraint ID "%{id}" does not exist') % { :id => @id }
      return false
    end

    # Can just use crm configure load update here, it's trivial enough (because
    # we basically replace the object every time, rather than having to merge
    # like primitive, ms, etc.)

    # TODO(must): preserve rule IDs
    result = Invoker.instance.crm_configure_load_update shell_syntax
    unless result == true
      error _('Unable to update constraint: %{msg}') % { :msg => result }
      return false
    end

    true
  end
  
  def update_attributes(attributes = nil)
    @rules  = []
    @rsc    = ''
    super
  end

  # Can this rule be folded back to "location <id> <res> <score>: <node>
  def simple?
    @rules.none? ||
      @rules.length == 1 && rules[0][:expressions].length == 1 &&
        rules[0][:score] && rules[0][:expressions][0][:value] &&
        rules[0][:expressions][0][:attribute] == '#uname' &&
        rules[0][:expressions][0][:operation] == 'eq'
  end

  def too_complex?
    @too_complex ||= false
  end

  class << self
    def instantiate(xml)
      con = allocate
      rules = []
      if xml.attributes['score']
        # Simple location constraint, fold to rule notation
        rules << {
          :score => xml.attributes['score'],
          :expressions => [ {
              :attribute => '#uname',
              :operation => 'eq',
              :value     => xml.attributes['node']
          } ]
        }
      else
        # Rule notation
        xml.elements.each do |rule_elem|
          rule = {
            :id               => rule_elem.attributes['id'],
            :role             => rule_elem.attributes['role'] || nil,
            :score            => rule_elem.attributes['score'] || rule_elem.attributes['score-attribute'] || nil,
            :boolean_op       => rule_elem.attributes['boolean-op'] || 'and',
            :expressions      => []
          }
          rule_elem.elements.each do |expr_elem|
            if expr_elem.name != 'expression'
              # Considers nested rules and date_expression to be too complex
              # TODO(should): Handle date expressions
              con.instance_variable_set(:@too_complex, true)
              next
            end
            rule[:expressions] << {
              :value      => expr_elem.attributes['value'] || nil,
              :attribute  => expr_elem.attributes['attribute'] || nil,
              :type       => expr_elem.attributes['type'] || 'string',
              :operation  => expr_elem.attributes['operation'] || nil
            }
          end
          rules << rule
        end
      end
      con.instance_variable_set(:@rsc,   xml.attributes['rsc'])
      con.instance_variable_set(:@rules, rules)
      con
    end
  end

  private

  # Note: caller must ensure valid rule before calling this
  def shell_syntax
    cmd = "location #{@id} #{@rsc}"

    if simple?
      cmd += " #{@rules[0][:score]}: #{@rules[0][:expressions][0][:value]}"
    else
      # TBI
    end
  end
end
