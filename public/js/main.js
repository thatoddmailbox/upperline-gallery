$(document).ready(function() {
	$(".star").click(function() {
		if ($(this).hasClass("fa-spin")) {
			// we're still loading, go away
			return;
		}
		var token = $('meta[name="_csrf"]').attr('content');
		var id = $(this).attr("data-project-id");
		var starred = $(this).hasClass("fa-star");
		$(this).removeClass("fa-star").removeClass("fa-star-o");
		$(this).addClass("fa-refresh").addClass("fa-spin");
		$.ajax({
			method: "POST",
			url: "/set_starred",
			data: {
				csrf: token,
				id: id,
				starred: !starred
			},
			success: function(data) {
				console.log(data);
				if (data == "OK") {
					$(".star[data-project-id=" + id + "]").removeClass("fa-refresh").removeClass("fa-spin");
					$(".star[data-project-id=" + id + "]").addClass((!starred ? "fa-star" : "fa-star-o"));
				} else {
					alert(data);
				}
			}
		});
	});
});
