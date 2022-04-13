class schema_change_mon (
  $db_provider = "mysql",
  $db_user = "root",
  $db_pwd = "R00tP@55",
  $db_schema = []
) {
	
	$dbs = ['pauldb', 'sbtest']

	service { $db_provider :
		ensure       => running,
		enable       => true,
		hasrestart   => true,
		hasstatus    => true
	}
	

	exec { "mysql-without-primary-key" :
		require     => Service['mysql'],
		command => "/usr/bin/sudo MYSQL_PWD=\"${db_pwd}\" /usr/bin/mysql -u${db_user} -Nse \"select concat(tables.table_schema,'.',tables.table_name,', ', tables.engine) from information_schema.tables left join ( select table_schema , table_name from information_schema.statistics group by table_schema , table_name , index_name having  sum( case  when non_unique = 0  and nullable != 'YES' then 1  else 0  end ) = count(*) ) puks on tables.table_schema = puks.table_schema and tables.table_name = puks.table_name where puks.table_name is null and tables.table_type = 'BASE TABLE' and tables.table_schema not in ('performance_schema',  'information_schema', 'mysql');\" >> /opt/schema_change_mon/assets/no-pk.log"
	}

	$dbs.each |String $db| {
		exec { "mysql-duplicate-index-$db" :
			require     => Service['mysql'],
			command => "/usr/bin/sudo MYSQL_PWD=\"${db_pwd}\" /usr/bin/mysql -u${db_user} -Nse \"SELECT concat(t.table_schema,'.', t.table_name, '.', t.index_name, '(', t.idx_cols,')') FROM ( SELECT table_schema, table_name, index_name, Group_concat(column_name) idx_cols FROM ( SELECT table_schema, table_name, index_name, column_name FROM statistics WHERE table_schema='${db}' ORDER BY index_name, seq_in_index) t GROUP BY table_name, index_name) t JOIN ( SELECT table_schema, table_name, index_name, Group_concat(column_name) idx_cols FROM ( SELECT table_schema, table_name, index_name, column_name FROM statistics WHERE table_schema='pauldb' ORDER BY index_name, seq_in_index) t GROUP BY table_name, index_name) u where t.table_schema = u.table_schema AND t.table_name = u.table_name AND t.index_name<>u.index_name AND locate(t.idx_cols,u.idx_cols);\" information_schema >> /opt/schema_change_mon/assets/dupe-indexes.log"
		}
		
	}
	
	$genscript = "/tmp/graphing_gen.sh"
	
	file { "${genscript}" :
		ensure => present,
		owner  => root,
		group  => root,
		mode   => '0655',
		source => 'puppet:///modules/schema_change_mon/graphing_gen.sh'
	}

	exec { "generate-graph-total-rows" :
		require     => [Service['mysql'],File["${genscript}"]],
		path =>  [ '/bin/', '/sbin/' , '/usr/bin/', '/usr/sbin/' ],
		provider => "shell",
		logoutput => true,
		command => "/tmp/graphing_gen.sh total_rows"
	}

	exec { "generate-graph-total-len" :
		require  => [Service['mysql'],File["${genscript}"]],
		path 	 =>  [ '/bin/', '/sbin/' , '/usr/bin/', '/usr/sbin/' ],
		provider => "shell",
		logoutput => true,
		command => "/tmp/graphing_gen.sh total_len"
	}
	
}
