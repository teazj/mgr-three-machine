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

        $sql = "update t3 set name='{$startTime}_333',sex='{$startTime}_333' where id='3'";
        mysql_query($sql);
        mysql_close($conn);
}
