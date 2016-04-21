class Photo

	attr_accessor :id, :location
	attr_writer :contents

	def self.mongo_client

		Mongoid::Clients.default

	end

	def initialize(params={})

		if params == {}
			return
		end
		@id = params[:_id].to_s
		@location = Point.new(params[:metadata][:location]) if !params[:metadata][:location].nil?

	end

	def persisted?

		!@id.nil?

	end

	def save

		if persisted?
			return
		end
		if @contents
			gps=EXIFR::JPEG.new(@contents).gps
			@contents.rewind
			@location=Point.new(:lng=>gps.longitude, :lat=>gps.latitude)
			description = {}
			description[:metadata] ={}
		    description[:metadata][:location]=@location.to_hash
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
		puts f.info
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

end