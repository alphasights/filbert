require 'rest_client'
require 'json'

class Log
  def initialize(task_name)
    @task_name = task_name
  end

  def success 
    RestClient.put(datastore, payload.to_json) unless datastore.nil?
  rescue RestClient::Exception 
    #just dont explode the back up task
  end

  private

  def datastore 
    ENV['FILBERT_LOG_URL']
  end

  def rev
    payload = RestClient.get(datastore)
    JSON.parse(payload)['_rev']
  end

  def payload 
    {
      "_rev" => rev,
      "app"=> "pistachio",
      "timestamp"=> Time.now.to_s,
      "js_timestamp" => Time.now.to_i, 
      "task_name" => task_name
    }
  end
end
