require 'RMagick'
module AttachmerbFu # :nodoc:
  module Processors
    module RmagickProcessor
      def self.included(base)
        base.send :extend, ClassMethods
        base.alias_method_chain :process_attachment, :processing
      end
      
      module ClassMethods
        # Yields a block containing an RMagick Image for the given binary data.
        def with_image(file, &block)
          begin
            binary_data = file.is_a?(Magick::Image) ? file : Magick::Image.read(file).first unless !Object.const_defined?(:Magick)
          rescue
            # Log the failure to load the image.  This should match ::Magick::ImageMagickError
            # but that would cause acts_as_attachment to require rmagick.
            logger.debug("Exception working with image: #{$!}")
            binary_data = nil
          end
          block.call binary_data if block && binary_data
        ensure
          !binary_data.nil?
        end
      end

    protected
      def process_attachment_with_processing
        return unless process_attachment_without_processing
        with_image do |img|
          resize_image_or_thumbnail! img
          self.width  = img.columns if respond_to?(:width)
          self.height = img.rows    if respond_to?(:height)
          callback_with_args :after_resize, img
        end if image?
      end
    
      # Performs the actual resizing operation for a thumbnail
      def resize_image(img, size)
        if size.is_a?(Array) && size.length == 1 && !size.first.is_a?(Fixnum)
          size = size.first 
        elsif size.is_a?(Array) && size.length == 2 && size[0].is_a?(Array) && size[0].length == 2
          size = size.inject({}) { |hsh, pair| hsh[pair[0]] = pair[1]; hsh }
        end
        if size.is_a?(Fixnum) || (size.is_a?(Array) && size.first.is_a?(Fixnum))
          size = [size, size] if size.is_a?(Fixnum)
          img.thumbnail!(size.first, size[1])
        elsif img.respond_to?(:crop_resized) && size.is_a?(Hash) && size[:width] && size[:height]
          gravity = magick_gravity rescue Magick::CenterGravity
          img.crop_resized!(size[:width], size[:height], gravity)
        else
          img.change_geometry(size.to_s) { |cols, rows, image| image.resize!(cols, rows) }
        end
        self.temp_path = write_to_temp_file(img.to_blob) if img
      end
    end
  end
end