class Place

  attr_accessor :id, :formatted_address, :location, :address_components

  def initialize(params)

  	@id = params[:_id].to_s 	
  	@address_components = []
  	params[:address_components].each {|comp| @address_components << AddressComponent.new(comp)} if !params[:address_components].nil?
  	@formatted_address = params[:formatted_address]  	
  	@location = Point.new(params[:geometry][:geolocation])  	

  end

  def self.mongo_client

  	Mongoid::Clients.default

  end

  def self.collection

  	@coll = self.mongo_client['places']

  end

  def self.load_all (io)
 
  	collection.insert_many(JSON.parse(File.read(io)))

  end

  def self.find_by_short_name (string)

    collection.find("address_components.short_name" => string)

  end

  def self.to_places (data)

    result = []
    data.each { |place| result << Place.new(place) }
    return result

  end

  def self.find id

    id = BSON::ObjectId.from_string(id)
    result = collection.find(:_id => id).first
    result = Place.new(result) if !result.nil?
  end

  def self.all(offset=0,limit=nil)

    result = []
    data = collection.find.skip(offset)
    data = data.limit(limit) if !limit.nil?
    data.each {|place| result << Place.new(place)}
    return result
  end

  def destroy

    self.class.collection.find(:_id => BSON::ObjectId.from_string(@id)).delete_one

  end

  def self.get_address_components(sort={:_id => 1},offset=0,limit=nil)

    if !limit.nil?
      data = collection.aggregate( [ { :$unwind => "$address_components" }, {:$project => {:_id => 1, :address_components => 1, :formatted_address => 1, "geometry.geolocation" => 1}}, {:$sort => sort}, {:$skip => offset}, {:$limit => limit}] )
    else
      data = collection.aggregate( [ { :$unwind => "$address_components" }, {:$project => {:_id => 1, :address_components => 1, :formatted_address => 1, "geometry.geolocation" => 1}}, {:$sort => sort}, {:$skip => offset}] )
    end
    return data

  end

  def self.get_country_names

    data = collection.aggregate([{:$unwind => "$address_components"}, {:$project => {"address_components.long_name" =>1, "address_components.types" => 1}}, {:$match => {"address_components.types" => "country"}}, {:$group => {:_id => "$address_components.long_name"}}]).to_a.map {|h| h[:_id]}
   
  end

  def self.find_ids_by_country_code (country_code)

    data = collection.aggregate([{:$match => {"address_components.types" => "country", "address_components.short_name" => country_code}}, {:$project => {:_id => 1}}]).map {|doc| doc[:_id].to_s}

  end

  def self.create_indexes

    collection.indexes.create_one("geometry.geolocation" => Mongo::Index::GEO2DSPHERE)

  end

  def self.remove_indexes

    Place.collection.indexes.drop_one("geometry.geolocation_2dsphere")

  end

  def self.near (point, max_meters=nil)

    Place.collection.find({"geometry.geolocation" => {:$near => { :$geometry => point.to_hash, :$maxDistance => max_meters}}})

  end

  def near (distance=nil)

    Place.to_places(Place.near(@location,distance))

  end

  def photos (offset = 0,limit = nil)

    result = Photo.find_photos_for_place(@id).skip(offset)
    result = result.limit(limit) if !limit.nil?
    return result.to_a

  end

end