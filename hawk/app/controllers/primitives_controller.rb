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

class PrimitivesController < ApplicationController
  before_filter :login_required

  layout 'main'
  # Need cib for both edit and update (but ultimately want to minimize the amount of processing...)
  # TODO(should): consolidate/refactor with scaffolding in crm_config_controller
  before_filter :get_cib

  def get_cib
    @cib = Cib.new params[:cib_id], current_user
  end

  def initialize
    super
    @title = _('Edit Resource')
  end

  def new
    @title = _('Create Resource')
    @res = Primitive.new
  end

  def create
    @title = _('Create Resource')
    unless params[:cancel].blank?
      redirect_to status_path
      return
    end
    @res = Primitive.new params[:primitive]
    if @res.save
      flash[:highlight] = _('Resource created successfully')
      redirect_to :action => 'edit', :id => @res.id
    else
      render :action => 'new'
    end
  end

  def edit
    @res = Primitive.find params[:id]
  end

  def update
    unless params[:revert].blank?
      redirect_to :action => 'edit'
      return
    end
    unless params[:cancel].blank?
      redirect_to status_path
      return
    end
    @res = Primitive.find params[:id]
    if @res.update_attributes(params[:primitive])
      flash[:highlight] = _('Resource updated successfully')
      redirect_to :action => 'edit', :id => @res.id
    else
      render :action => 'edit'
    end
  end

  def types
    render :json => Primitive.types(params[:r_class], params.has_key?(:r_provider) ? params[:r_provider] : '')
  end

  def meta
    render :json => Primitive.meta(params[:r_class], params.has_key?(:r_provider) ? params[:r_provider] : '', params[:r_type])
  end
end
