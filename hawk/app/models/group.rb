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

class Group < CibObject
  include GetText

  attr_accessor :children

  def initialize(attributes = nil)
    @new_record = true
    @id         = nil
    @children   = []
    unless attributes.nil?
      ['id', 'children'].each do |n|
        instance_variable_set("@#{n}".to_sym, attributes[n]) if attributes.has_key?(n)
      end
    end
  end

  def save
    if @id.match(/[^a-zA-Z0-9_-]/)
      error _('Invalid Resource ID "%{id}"') % { :id => @id }
    end

    if @children.empty?
      error _('No group children specified')
    end

    return false if errors.any?

    if new_record?
      if CibObject.id_exists?(id)
        error _('The ID "%{id}" is already in use') % { :id => @id }
        return false
      end

      # TODO(must): Ensure children are sanitized
      cmd = "group #{@id}"
      @children.each do |c|
        cmd += " #{c}"
      end
      cmd += "\ncommit\n"

      result = Invoker.instance.crm_configure cmd
      unless result == true
        error _('Unable to create group: %{msg}') % { :msg => result }
        return false
      end

      return true
    else
      # Saving an existing group
      unless Group.exists?(id)
        error _('Group ID "%{id}" does not exist') % { :id => @id }
        return false
      end

      # Actually nothing to do here - groups once created can't
      # be edited (yet)
      return true
    end

    false  # Never reached
  end

  def update_attributes(attributes)
    # Nothing to do here (yet)
    save
  end

  class << self

    # Check whether a group with the given ID exists
    # TODO(must): Consolidate with Primitive.exists, move to CibObject?
    def exists?(id)
      # TODO(must): sanitize ID
      %x[/usr/sbin/cibadmin -Ql --xpath '//group[@id="#{id}"]' 2>/dev/null].index('<group') ? true : false
    end

    def find(id)
      begin
        xml = REXML::Document.new(Invoker.instance.cibadmin('-Ql', '--xpath', "//group[@id='#{id}']"))
        raise CibObject::CibObjectError, _('Unable to parse cibadmin output') unless xml.root

        g = xml.elements['group']
        res = allocate
        res.instance_variable_set(:@id, id)
        res.instance_variable_set(:@children, g.elements.map {|e| e.attributes['id'] })
        res
      rescue SecurityError => e
        raise CibObject::PermissionDenied, e.message
      rescue NotFoundError => e
        raise CibObject::RecordNotFound, e.message
      rescue RuntimeError => e
        raise CibObject::CibObjectError, e.message
      end
    end
  end

end
