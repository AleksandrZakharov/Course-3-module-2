class Point
	attr_accessor :longitude, :latitude

	def to_hash
		
	      jsoncoord = {:type => "Point", :coordinates => [@longitude, @latitude]}
    
	end

	def initialize (params)

		
		if params[:lat]
			@longitude=params[:lng]
	      	@latitude=params[:lat]
	    end
		if params[:coordinates]
	      	@longitude=params[:coordinates][0]
	      	@latitude=params[:coordinates][1]
	    end

    end

	

end