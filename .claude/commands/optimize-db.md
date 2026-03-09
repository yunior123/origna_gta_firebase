# /optimize-db - Optimize database queries and costs

**Usage**: `/optimize-db [--analyze|--fix]`

## What it does:
1. Scans for N+1 query patterns
2. Identifies missing indexes
3. Checks for inefficient pagination
4. Reviews batch operations
5. Calculates read/write costs
6. Suggests optimizations

## Examples:
```
/optimize-db --analyze
/optimize-db --fix
```

## Optimization Targets:
```yaml
firestore:
  - Eliminate N+1 queries → Batch reads
  - Add missing composite indexes
  - Implement pagination (limit + startAfter)
  - Use lazy loading for large collections
  - Cache frequently accessed data
  
cost_reduction:
  - Reduce reads by 50%+
  - Reduce writes by 30%+
  - Implement request deduplication
  - Add client-side caching
```

## Auto-fixes:
- ✅ Convert loops to batch operations
- ✅ Add limit() to unbounded queries
- ✅ Implement cursor-based pagination
- ✅ Add composite indexes to firestore.indexes.json
- ✅ Add caching layer
