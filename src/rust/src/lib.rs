use extendr_api::prelude::*;
use lbug::{Connection, Database, SystemConfig, QueryResult, Value, NodeVal, RelVal, InternalID};
use std::collections::HashMap;

// Wrapper struct to hold both Database and Connection
struct LbugConnection {
    db: Box<Database>,
    conn: Connection<'static>,
}

impl LbugConnection {
    fn new(path: &str) -> Result<Self, String> {
        let db = Box::new(
            Database::new(path, SystemConfig::default())
                .map_err(|e| format!("Failed to create database: {}", e))?
        );
        
        // SAFETY: db is boxed and won't move. Connection borrows from db,
        // and both live in the same struct owned by the R external pointer.
        let db_ref: &'static Database = unsafe { &*(db.as_ref() as *const Database) };
        let conn = Connection::new(db_ref)
            .map_err(|e| format!("Failed to create connection: {}", e))?;
        
        Ok(LbugConnection { db, conn })
    }
}

// Create a connection to a Ladybug database
#[extendr]
fn lbug_connect(path: &str) -> ExternalPtr<LbugConnection> {
    match LbugConnection::new(path) {
        Ok(conn) => ExternalPtr::new(conn),
        Err(e) => panic!("{}", e),
    }
}

// Execute a Cypher query and return results as an R data.frame
#[extendr]
fn lbug_execute(conn: &ExternalPtr<LbugConnection>, query: &str) -> Robj {
    let result = conn.conn.query(query)
        .expect("Query execution failed");
    
    query_result_to_dataframe(result)
}

// Shutdown the database connection
#[extendr]
fn lbug_shutdown(conn: ExternalPtr<LbugConnection>) {
    drop(conn);
}

// Check if the Rust library is available
#[extendr]
fn lbug_is_available() -> bool {
    true
}

// Convert a QueryResult to an R data.frame
fn query_result_to_dataframe(result: QueryResult) -> Robj {
    let col_names = result.get_column_names();
    let _col_types = result.get_column_data_types();
    
    // Collect all rows using Iterator trait
    let rows: Vec<Vec<Value>> = result.collect();
    
    // Determine which columns need expansion (Node/Rel)
    let mut expanded_cols: Vec<(String, Vec<String>)> = Vec::new();
    let mut simple_cols: Vec<(String, usize)> = Vec::new();
    
    for (i, col_name) in col_names.iter().enumerate() {
        let needs_expansion = rows.iter().any(|row| {
            matches!(&row[i], Value::Node(_) | Value::Rel(_))
        });
        
        if needs_expansion {
            let mut fields = Vec::new();
            for row in &rows {
                match &row[i] {
                    Value::Node(node) => {
                        fields.extend(get_node_fields(node));
                    }
                    Value::Rel(rel) => {
                        fields.extend(get_rel_fields(rel));
                    }
                    _ => {}
                }
            }
            fields.sort();
            fields.dedup();
            expanded_cols.push((col_name.clone(), fields));
        } else {
            simple_cols.push((col_name.clone(), i));
        }
    }
    
    // Build column data
    let mut columns: Vec<(String, Robj)> = Vec::new();
    
    // Process simple columns
    for (col_name, col_idx) in &simple_cols {
        let col_data = build_simple_column(&rows, *col_idx);
        columns.push((col_name.clone(), col_data));
    }
    
    // Process expanded columns (Node/Rel)
    for (col_name, fields) in &expanded_cols {
        for field in fields {
            let field_col_name = format!("{}.{}", col_name, field);
            let field_data = build_expanded_column(&rows, field);
            columns.push((field_col_name, field_data));
        }
    }
    
    // Create data.frame
    let n_rows = rows.len();
    let col_names_str: Vec<&str> = columns.iter().map(|(name, _)| name.as_str()).collect();
    let col_values_r: Vec<Robj> = columns.iter().map(|(_, val)| val.clone()).collect();
    
    let mut df = List::from_values(&col_values_r);
    df.set_names(col_names_str.as_slice()).unwrap();
    df.set_class(&["data.frame"]).unwrap();
    df.set_attrib("row.names", r!((1..=n_rows as i32).collect::<Vec<_>>())).unwrap();
    
    df.into_robj()
}

// Get field names from a NodeVal
fn get_node_fields(node: &NodeVal) -> Vec<String> {
    let mut fields = vec![
        "_ID.offset".to_string(),
        "_ID.table".to_string(),
        "_LABEL".to_string(),
    ];
    
    for (prop_name, _) in node.get_properties() {
        fields.push(prop_name.clone());
    }
    
    fields
}

// Get field names from a RelVal
fn get_rel_fields(rel: &RelVal) -> Vec<String> {
    let mut fields = vec![
        "_ID.offset".to_string(),
        "_ID.table".to_string(),
        "_LABEL".to_string(),
        "_SRC.offset".to_string(),
        "_SRC.table".to_string(),
        "_DST.offset".to_string(),
        "_DST.table".to_string(),
    ];
    
    for (prop_name, _) in rel.get_properties() {
        fields.push(prop_name.clone());
    }
    
    fields
}

// Build a column for simple (non-expanded) values
fn build_simple_column(rows: &[Vec<Value>], col_idx: usize) -> Robj {
    let values: Vec<&Value> = rows.iter().map(|row| &row[col_idx]).collect();
    
    if values.is_empty() {
        return r!(());
    }
    
    let first_non_null = values.iter().find(|v| !matches!(v, Value::Null(_)));
    
    match first_non_null {
        Some(Value::Bool(_)) => {
            let vals: Vec<Robj> = values.iter().map(|v| {
                match v {
                    Value::Bool(b) => r!(*b),
                    Value::Null(_) => r!(NA_LOGICAL),
                    _ => r!(NA_LOGICAL),
                }
            }).collect();
            R!(c(!!!vals)).unwrap()
        }
        Some(Value::Int64(_)) | Some(Value::Int32(_)) | Some(Value::Int16(_)) | Some(Value::Int8(_)) => {
            let vals: Vec<Robj> = values.iter().map(|v| {
                match v {
                    Value::Int64(n) => r!(*n as i32),
                    Value::Int32(n) => r!(*n),
                    Value::Int16(n) => r!(*n as i32),
                    Value::Int8(n) => r!(*n as i32),
                    Value::Null(_) => r!(NA_INTEGER),
                    _ => r!(NA_INTEGER),
                }
            }).collect();
            R!(c(!!!vals)).unwrap()
        }
        Some(Value::UInt64(_)) | Some(Value::UInt32(_)) | Some(Value::UInt16(_)) | Some(Value::UInt8(_)) => {
            let vals: Vec<Robj> = values.iter().map(|v| {
                match v {
                    Value::UInt64(n) => r!(*n as f64),
                    Value::UInt32(n) => r!(*n as f64),
                    Value::UInt16(n) => r!(*n as f64),
                    Value::UInt8(n) => r!(*n as f64),
                    Value::Null(_) => r!(NA_REAL),
                    _ => r!(NA_REAL),
                }
            }).collect();
            R!(c(!!!vals)).unwrap()
        }
        Some(Value::Double(_)) | Some(Value::Float(_)) => {
            let vals: Vec<Robj> = values.iter().map(|v| {
                match v {
                    Value::Double(n) => r!(*n),
                    Value::Float(n) => r!(*n as f64),
                    Value::Null(_) => r!(NA_REAL),
                    _ => r!(NA_REAL),
                }
            }).collect();
            R!(c(!!!vals)).unwrap()
        }
        Some(Value::String(_)) => {
            let vals: Vec<Robj> = values.iter().map(|v| {
                match v {
                    Value::String(s) => r!(s.as_str()),
                    Value::Null(_) => r!(NA_STRING),
                    _ => r!(NA_STRING),
                }
            }).collect();
            R!(c(!!!vals)).unwrap()
        }
        Some(Value::Date(_)) => {
            let vals: Vec<Robj> = values.iter().map(|v| {
                match v {
                    Value::Date(d) => {
                        // Convert time::Date to days since epoch using Julian day
                        let epoch_jd = 2440588; // Julian day for 1970-01-01
                        let days = (d.to_julian_day() - epoch_jd) as i32;
                        r!(days)
                    },
                    Value::Null(_) => r!(NA_INTEGER),
                    _ => r!(NA_INTEGER),
                }
            }).collect();
            let result = R!(c(!!!vals)).unwrap();
            let mut date_vec = result;
            date_vec.set_class(&["Date"]).unwrap();
            date_vec
        }
        Some(Value::Timestamp(_)) | Some(Value::TimestampTz(_)) | Some(Value::TimestampNs(_)) | 
        Some(Value::TimestampMs(_)) | Some(Value::TimestampSec(_)) => {
            let vals: Vec<Robj> = values.iter().map(|v| {
                match v {
                    Value::Timestamp(ts) | Value::TimestampTz(ts) | Value::TimestampNs(ts) | 
                    Value::TimestampMs(ts) | Value::TimestampSec(ts) => {
                        r!(ts.unix_timestamp() as f64 + ts.nanosecond() as f64 / 1_000_000_000.0)
                    },
                    Value::Null(_) => r!(NA_REAL),
                    _ => r!(NA_REAL),
                }
            }).collect();
            let result = R!(c(!!!vals)).unwrap();
            let mut posixct_vec = result;
            posixct_vec.set_class(&["POSIXct", "POSIXt"]).unwrap();
            posixct_vec
        }
        _ => {
            let vals: Vec<Robj> = values.iter().map(|v| {
                match v {
                    Value::Null(_) => r!(NA_STRING),
                    _ => r!(format!("{}", v)),
                }
            }).collect();
            R!(c(!!!vals)).unwrap()
        }
    }
}

// Build a column for expanded (Node/Rel) fields
fn build_expanded_column(rows: &[Vec<Value>], field: &str) -> Robj {
    let _values: Vec<Robj> = rows.iter().map(|row| {
        for value in row {
            match value {
                Value::Node(node) => return extract_node_field(node, field),
                Value::Rel(rel) => return extract_rel_field(rel, field),
                _ => continue,
            }
        }
        r!(NA_LOGICAL)
    }).collect();
    
    R!(c(!!!_values)).unwrap()
}

// Extract a field from a NodeVal
fn extract_node_field(node: &NodeVal, field: &str) -> Robj {
    match field {
        "_ID.offset" => {
            let id = node.get_node_id();
            r!(id.offset as i32)
        }
        "_ID.table" => {
            let id = node.get_node_id();
            r!(id.table_id as i32)
        }
        "_LABEL" => {
            let label = node.get_label_name();
            r!(label.as_str())
        }
        _ => {
            for (prop_name, prop_value) in node.get_properties() {
                if prop_name == field {
                    return value_to_robj(prop_value);
                }
            }
            r!(NA_LOGICAL)
        }
    }
}

// Extract a field from a RelVal
fn extract_rel_field(rel: &RelVal, field: &str) -> Robj {
    match field {
        "_ID.offset" | "_ID.table" => {
            // RelVal doesn't expose its own ID in the Rust API
            // Use NA as placeholder
            r!(NA_INTEGER)
        }
        "_LABEL" => {
            let label = rel.get_label_name();
            r!(label.as_str())
        }
        "_SRC.offset" => {
            let src = rel.get_src_node();
            r!(src.offset as i32)
        }
        "_SRC.table" => {
            let src = rel.get_src_node();
            r!(src.table_id as i32)
        }
        "_DST.offset" => {
            let dst = rel.get_dst_node();
            r!(dst.offset as i32)
        }
        "_DST.table" => {
            let dst = rel.get_dst_node();
            r!(dst.table_id as i32)
        }
        _ => {
            for (prop_name, prop_value) in rel.get_properties() {
                if prop_name == field {
                    return value_to_robj(prop_value);
                }
            }
            r!(NA_LOGICAL)
        }
    }
}

// Convert a Value to an R object
fn value_to_robj(value: &Value) -> Robj {
    match value {
        Value::Null(_) => r!(NA_LOGICAL),
        Value::Bool(b) => r!(*b),
        Value::Int64(n) => r!(*n as i32),
        Value::Int32(n) => r!(*n),
        Value::Int16(n) => r!(*n as i32),
        Value::Int8(n) => r!(*n as i32),
        Value::UInt64(n) => r!(*n as f64),
        Value::UInt32(n) => r!(*n as f64),
        Value::UInt16(n) => r!(*n as f64),
        Value::UInt8(n) => r!(*n as f64),
        Value::Double(n) => r!(*n),
        Value::Float(n) => r!(*n as f64),
        Value::String(s) => r!(s.as_str()),
        Value::Date(d) => {
            let epoch_jd = 2440588;
            let days = (d.to_julian_day() - epoch_jd) as i32;
            let mut date_vec = r!(days);
            date_vec.set_class(&["Date"]).unwrap();
            date_vec
        }
        Value::Timestamp(ts) | Value::TimestampTz(ts) | Value::TimestampNs(ts) | 
        Value::TimestampMs(ts) | Value::TimestampSec(ts) => {
            let seconds = ts.unix_timestamp() as f64 + ts.nanosecond() as f64 / 1_000_000_000.0;
            let mut posixct_vec = r!(seconds);
            posixct_vec.set_class(&["POSIXct", "POSIXt"]).unwrap();
            posixct_vec
        }
        _ => r!(format!("{}", value)),
    }
}

// Macro to generate exports
extendr_module! {
    mod lbugr;
    fn lbug_connect;
    fn lbug_execute;
    fn lbug_shutdown;
    fn lbug_is_available;
}
