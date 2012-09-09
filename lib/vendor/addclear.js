// Author: Stephen Korecky
// Website: http://stephenkorecky.com
// Plugin Website: http://github.com/skorecky/Add-Clear

(function($){  
	$.fn.extend({   
		addClear: function(options) {  
			var options =  $.extend({  
				closeImage: "clear.png",
				top: 0,
				right: 4,
				returnFocus: true,
				showOnLoad: false,
				onClear: null
				}, options);

				$(this).wrap("<span style='position:relative;' class='add-clear-span'>");

				// CUSTOMIZATION: Use fontawesome glyph.
				$(".add-clear-span").append("<a href='#clear'><i class='icon-large icon-remove-sign'></i></a>");
				// $(".add-clear-span").append("<a href='#clear'>clear</a>");

				$("a[href='#clear']").css({

					// CUSTOMIZATION: No image.
					// 'background' : 'transparent url('+options.closeImage+') 0 0 no-repeat',

					'display' : 'none',
					'height' : '16px',
					'overflow' : 'hidden',
					'position' : 'absolute',
					'right' : options.right+'px',

					// CUSTOMIZATION: Show the text and make it gray.
					// 'text-indent' : '-9999px',
					'color' : 'gray',

					'top' : options.top+'px',
					'width' : '16px'
					}, this);
					
					if($(this).val().length >= 1 && options.showOnLoad === true) {
						$(this).siblings("a[href='#clear']").show();
					}
					
					$(this).keyup(function() {
						if($(this).val().length >= 1) {
							$(this).siblings("a[href='#clear']").show();
						} else {
							$(this).siblings("a[href='#clear']").hide();
						}
					});

					$("a[href='#clear']").click(function(){
						$(this).siblings("input").val("");
						$(this).hide();
						if(options.returnFocus === true){
							$(this).siblings("input").focus();
						}
						if (options.onClear){
              options.onClear($(this).siblings("input"));
            }
						return false;
					});
					return this; 
				}  
			});  
			})(jQuery);