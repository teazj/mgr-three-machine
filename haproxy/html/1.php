<?php
header("content-type:text/html;charset=utf-8");
$conn=@mysql_connect("127.0.0.1:6033","sbuser","sbpass");

if(!$conn){
        echo "<h2>错误编码:".mysql_errno()."</h2>";
        echo "<h2>错误编码:".mysql_error()."</h2>";
}else{

        mysql_select_db("sbtest");
        mysql_query("set names utf8");

        $sql = "select count(*) from sbtest";
        mysql_query($sql);
        mysql_close($conn);
}
