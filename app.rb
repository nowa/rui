# -*- encoding : utf-8 -*-
$LOAD_PATH.unshift(File.dirname(__FILE__)) unless $LOAD_PATH.include?(File.dirname(__FILE__))

require 'bundler/setup'
require 'sinatra'
require 'sinatra/base'
require 'mtik'

# RUI Utils
module RUIUtils
  # get layer7 protocols which named 'GFWed'
  def get_layer7_domains(name='GFWed')
    @mt.get_reply(
      '/ip/firewall/layer7-protocol/getall', 
      "?name=#{name}"
    ) do |request, sentence|
      logger.info "#{request.reply}"
      trap = request.reply.find_sentence('!trap')
      if trap.nil?
        re = request.reply.find_sentence('!re')
        unless re.nil?
          return re['regexp']
        else
          logger.info "#{settings.rui_host}: WARNING: "
        end
      end
    end
    
    return ""
  end
  
  # set layer7 protocols
  def set_layer7_domains(domains, id=0)
    logger.info "domains: #{params['domains']}"
    message = ""
    @mt.get_reply(
      '/ip/firewall/layer7-protocol/set', 
      "=.id=#{id}", 
      "=regexp=#{domains}"
    ) do |request, sentence|
      logger.info "#{request.reply}"
      trap = request.reply.find_sentence('!trap')
      if trap.nil?
        message = "#{settings.rui_host}: Layer7 protocols update command was sent."
      else
        message = "#{settings.rui_host}: An error occurred while setting layer7 protocols: #{trap['message']}"
      end
    end
    
    return message
  end
  
  # add ip addresses to address-list
  def add_ip_addresses(addresses, comment="", list="GFWed")
    logger.info "addresses: #{addresses}"
    message = ""
    counter = 0
    addresses.gsub!("\r", "")
    addresses.split("\n").each do |address|
      counter += 1
      message += add_ip_address(address, comment, list, false)
    end
    
    message = message == "" ? "#{settings.rui_host}: #{counter} ip addresses add commands was sent." : message
    return message
  end
  
  def add_ip_address(address, comment="", list="GFWed", need_successful_message=true)
    logger.info "address: #{address}"
    message = ""
    @mt.get_reply(
      '/ip/firewall/address-list/add', 
      "=list=#{list}", 
      "=address=#{address}", 
      "=comment=#{comment}"
    ) do |request, sentence|
      logger.info "#{request.reply}"
      trap = request.reply.find_sentence('!trap')
      if trap.nil?
        message = need_successful_message ? "#{settings.rui_host}: Command add ip #{address} to address-list was sent." : ""
      else
        message = "#{settings.rui_host}: An error occurred while add ip #{address} to address-list: #{trap['message']}\n"
      end
    end
    
    return message
  end
end

class RUI < Sinatra::Base
  # puma as app server
  configure { 
    set :server, :puma 
    set :rui_user, 'admin'
    set :rui_pwd, ''
    set :rui_host, '192.168.88.1'
    enable :logging
    enable :sessions
  }
  
  # helpers
  helpers RUIUtils

  # set public folder
  set :public_folder, File.dirname(__FILE__) + '/static'
  
  # connect to ros before every request
  before do
    @mt = nil
    begin
      @mt = MTik::Connection.new(
        :host => settings.rui_host,
        :user => settings.rui_user,
        :pass => settings.rui_pwd
      )
    rescue Errno::ETIMEDOUT, Errno::ENETUNREACH, Errno::EHOSTUNREACH => e
      logger.info "#{settings.rui_host}: Error connecting: #{e}"
    end
  end
  
  # close the connect after request
  after do
    @mt.close
  end

  # index
  get '/' do
    logger.info "header: #{request['RUI-Client']}"
    @domains = get_layer7_domains('to_google_DNS')
    erb :index
  end
  
  get '/new_address' do
    erb :new_address
  end
  
  get '/new_addresses' do
    erb :new_addresses
  end
  
  post '/address' do
    if params['address'].nil?
      notice = "IP Address can't be blank."
      logger.info notice
    else
      notice = add_ip_address(params['address'], params['comment'])
    end
    
    session[:notice] = notice
    redirect to('/new_address')
  end
  
  # add one or more addresses to address-list
  post '/addresses' do
    if params['addresses'].nil?
      notice = "IP Addresses can't be blank."
    else
      notice = add_ip_addresses(params['addresses'], params['comment'])
    end
    
    session[:notice] = notice
    redirect to('/new_addresses')
  end
  
  # append one or more layer7 protocol domains which named 'GFWed'
  post '/domains' do
    if params['domains'].nil?
      notice = "Domains regexp can't be blank."
    else
      notice = set_layer7_domains(params['domains'])
    end
    
    session[:notice] = notice
    redirect to('/')
  end
  
  # append a domain to layer7 protocols
  post '/domain' do
    if params['domain'].nil?
      notice = "Domain can't be blank."
    else
      domains = get_layer7_domains
      notice = set_layer7_domains("#{notice}|#{domains}")
    end
    
    session[:notice] = notice
    redirect to('/')
  end
  
  # start the server if ruby file executed directly
  run! if app_file == $0
end

