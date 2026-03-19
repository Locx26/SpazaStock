# DATABASE_SCHEMA

## Tables

### Product
- **id**: Integer, Primary Key
- **name**: Text, Not Null
- **created_at**: DateTime, Default (current_timestamp)
- **updated_at**: DateTime, Default (current_timestamp)

### StockMovement
- **id**: Integer, Primary Key
- **product_id**: Integer, Foreign Key (references Product)
- **quantity**: Integer, Not Null
- **movement_type**: Text, Not Null (e.g., 'in', 'out')
- **timestamp**: DateTime, Default (current_timestamp)

### Sale
- **id**: Integer, Primary Key
- **product_id**: Integer, Foreign Key (references Product)
- **quantity**: Integer, Not Null
- **sale_price**: Real, Not Null
- **timestamp**: DateTime, Default (current_timestamp)

### Tag
- **id**: Integer, Primary Key
- **name**: Text, Not Null, Unique

### SyncQueue
- **id**: Integer, Primary Key
- **table_name**: Text, Not Null
- **record_id**: Integer, Not Null
- **operation**: Text, Not Null (e.g., 'insert', 'update', 'delete')
- **timestamp**: DateTime, Default (current_timestamp)

## Relationships

- **Product** has many **StockMovement**
- **Product** has many **Sale**
- **Tag** can be associated with many **Product** (Many-to-Many relationship)
- **SyncQueue** records operations for all tables (Product, StockMovement, Sale, Tag) and their records.