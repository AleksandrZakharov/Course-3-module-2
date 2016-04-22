class Photo

	attr_accessor :id, :location
	attr_writer :contents
	@place

	def self.mongo_client

		Mongoid::Clients.default

	end

	def initialize(params={})

		if params == {}
			return
		end
		@id = params[:_id].to_s
		@location = Point.new(params[:metadata][:location]) if !params[:metadata][:location].nil?
		@place = params[:metadata][:place]

	end

	def persisted?

		!@id.nil?

	end

	def save

		if persisted?
			Photo.mongo_client.database.fs.find(:_id=>BSON::ObjectId.from_string(@id)).update_one(:$set => { "metadata" => { "location" => {"type"=>"Point", "coordinates" => [@location.longitude, @location.latitude]}, "place" => @place}})
			return
		end
		if @contents
			gps=EXIFR::JPEG.new(@contents).gps
			@contents.rewind
			@location=Point.new(:lng=>gps.longitude, :lat=>gps.latitude)
			description = {}
			description[:metadata] ={}
		    description[:metadata][:location] = @location.to_hash
		    description[:metadata][:place] = @place
		    description[:content_type]='image/jpeg'
		    grid_file = Mongo::Grid::File.new(@contents.read,description)

		    id=self.class.mongo_client.database.fs.insert_one(grid_file)
			
		    @id=id.to_s
		    @id
		end

	end

	def self.all (offset=0,limit=nil)

    	result = Photo.mongo_client.database.fs.find.skip(offset)
    	result = result.limit(limit) if !limit.nil?
    	result.map{|doc| Photo.new(doc) }

	end

	def self.find (id)

		Photo.new(Photo.mongo_client.database.fs.find(:_id=>BSON::ObjectId.from_string(id)).first) if !Photo.mongo_client.database.fs.find(:_id=>BSON::ObjectId.from_string(id)).first.nil?

	end

	def contents

		f=self.class.mongo_client.database.fs.find_one(:_id=>BSON::ObjectId.from_string(@id))
		if f 
	      buffer = ""
	      f.chunks.reduce([]) do |x,chunk| 
	          buffer << chunk.data.data 
	      end
	      return buffer
	    end

	end

	def destroy

		Photo.mongo_client.database.fs.find(:_id=>BSON::ObjectId.from_string(@id)).delete_one

	end

	def find_nearest_place_id (distance)

		Place.near(@location,distance).limit(1).projection(:_id => 1).first[:_id]

	end

	def place

		Place.find(@place) if !@place.nil?

	end

	def place= (place)

		case

			when place.is_a?(Place)
				@place=BSON::ObjectId.from_string(place.id)
			when place.is_a?(BSON::ObjectId)
				@place=place
			when place.is_a?(String)
				BSON::ObjectId.from_string(place)
		end
		
	end

	def self.find_photos_for_place (place)

		id = place.is_a?(BSON::ObjectId) ? place : BSON::ObjectId.from_string(place)
		Photo.mongo_client.database.fs.find("metadata.place" => BSON::ObjectId.from_string(id))

	end

end