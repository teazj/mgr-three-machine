<?php
header("content-type:text/html;charset=utf-8");
$conn=@mysql_connect("127.0.0.1","prodba","12wsxCDE#");

if(!$conn){
        echo "<h2>错误编码:".mysql_errno()."</h2>";
        echo "<h2>错误编码:".mysql_error()."</h2>";
}else{

        mysql_select_db("test");
        mysql_query("set names utf8");

        $mtime=explode(' ',microtime());
        $startTime=$mtime[1]+$mtime[0];

        $sql = "insert into t3(balance,name1,name2,name3) values ('$startTime','$startTime','$startTime','$startTime')";
        mysql_query($sql);
        mysql_close($conn);
}
