$(document).ready(function() {
  var data = {};
  $.ajax({
    type: "GET",
    dataType: "json",
    // url:"http://172.17.0.1:8080/ip",
    url:"https://qw8yyssvdd.execute-api.sa-east-1.amazonaws.com",
    data: data,
    success: function(data) {
      // var src_ip=JSON.stringify(data.ip);
      var src_ip=JSON.stringify(data.requestContext.http.sourceIp);
      var context=JSON.stringify(data);
      $('.src_ip').append(src_ip);
      //alert(context);
      console.log(context);
    },error: function(data) {
      alert("error!");
    }
  });
});