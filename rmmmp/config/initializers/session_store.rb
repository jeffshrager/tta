# Be sure to restart your server when you modify this file.

Rmmmp::Application.config.session_store :cookie_store, :key => '_rmmmp_session'

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
#Rmmmp::Application.config.session_store :data_mapper_store
#require 'dm-rails/session_store'
#Rmmmp::Application.config.session_store Rails::DataMapper::SessionStore
#Rmmmp::Application.config.session_store.session_id.length = 255
#Rmmmp::Application.config.session_store.session_class.session_id.instance_variable_set("@length", 255)