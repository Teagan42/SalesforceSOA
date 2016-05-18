public class QueryFactory
{
    public enum SortOrder
    {
        ASCENDING,
        DESCENDING
    }

    /**
     * The SObjectType token that will be used in the FROM clause of the query
     **/
    public SObjectType table { get; private set; }

    private Set<QueryField> fields;
    private String conditionExpression;
    private Integer limitCount;
    private Integer offset;
    private List<Ordering> order;
    private Boolean enforceFLS;
    private Boolean sortSelectFields = true;
    private ChildRelationship relationship;
    private Map<ChildRelationship, QueryFactory> subselectQueryMap;

    private QueryField getFieldToken(String fieldName)
    {
        QueryField result;

        if (!fieldName.contains('.'))
        {
            // Single Field
            SObjectField token = fflib_SObjectDescribe.getDescribe(table).getField(fieldName.toLowerCase());
            if (token == null)
            {
                throw new InvalidFieldException(fieldName,this.table);
            }

            if (enforceFLS)
            {
                SecurityUtils.checkFieldIsReadable(this.table, token);
            }

            result = new QueryField(token);
        }
        else
        {
            // Traverse relationships
            List<SObjectField> fieldPath = new List<SObjectField>();
            SObjectType lastSObjectType = table;
            Iterator<String> i = fieldName.split('\\.').iterator();
            while (i.hasNext())
            {
                String field = i.next();
                SObjectField token = fflib_SObjectDescribe.getDescribe(lastSObjectType).getField(field.toLowerCase());

                if (token != null && enforceFLS)
                {
                    SecurityUtils.checkFieldIsReadable(lastSObjectType, token);
                }

                if (token != null && i.hasNext() && token.getDescribe().getSOAPType() == Schema.SOAPType.ID)
                {
                    lastSObjectType = token.getDescribe().getReferenceTo()[0]; //if it's polymorphic doesn't matter which one we get
                    fieldPath.add(token);
                }
                else if (token != null && !i.hasNext())
                {
                    fieldPath.add(token);
                }
                else
                {
                    if (token == null)
                    {
                        throw new InvalidFieldException(field,lastSObjectType);
                    }
                    else
                    {
                        throw new NonReferenceFieldException(
                            lastSObjectType + '.' + field
                            + ' is not a lookup or master-detail field but is used in a cross-object query field.'
                        );
                    }
                }
            }

            result = new QueryField(fieldPath);
        }
        return result;
    }

    /**
     * Considered equal if:
     * - Tables match
     * - Field lists match
     * - SOQL generated match
     *
     * @param obj The object to check equality of.
     **/
    public boolean equals(Object obj)
    {
        if (!(obj instanceof QueryFactory)
            || ((QueryFactory)obj).table != this.table
            || ((QueryFactory)obj).fields.size() != this.fields.size())
        {
            return false;
        }

        return ((QueryFactory)obj).toSOQL() == this.toSOQL();
    }

    /**
     * Construct a new QueryFactory instance with no options other than the FROM caluse.
     * You *must* call selectField(s) before {@link #toSOQL} will return a valid, runnable query.
     *
     * @param table The SObject to be used in the FROM clause of the resultant query. This sets the value of {@link #table}.
     **/
    public QueryFactory(Schema.SObjectType table)
    {
        this.table = table;
        fields = new Set<QueryField>();
        order = new List<Ordering>();
        enforceFLS = false;
    }

    /**
     * Construct a new QueryFactory instance with no options other than the FROM clause and the relationship.
     * This should be used when constructing a subquery query for addition to a parent query.
     * You *must* call selectField(s) before {@link #toSOQL} will return a valid, runnable query.
     *
     * @param relationship The ChildRelationship to be used in the FROM Clause of the resultant Query (when set overrides value of table). This sets the value of {@link #relationship} and {@link #table}.
     **/
    private QueryFactory(Schema.ChildRelationship relationship)
    {
        this(relationship.getChildSObject());
        this.relationship = relationship;
    }

    /**
     * This method checks to see if the User has Read Access on {@link #table}.
     * Asserts true if User has access.
     **/
    public QueryFactory assertIsAccessible()
    {
        SecurityUtils.checkObjectIsReadable(table);
        return this;
    }

    /**
     * Flag enforcement for field level security
     *
     * @param enforce Flag for whether to enforce field level security (read)
     **/
    public QueryFactory setEnforceFLS(Boolean enforce)
    {
        this.enforceFLS = enforce;
        return this;
    }

    /**
     * Sets a flag to indicate that this query should have ordered
     * query fields in the select statement
     *
     * @param doSort Whether or not select fields should be sorted in the soql statement.
     **/
    public QueryFactory setSortSelectFields(Boolean doSort)
    {
        this.sortSelectFields = doSort;
        return this;
    }

    /**
     * Selects a single field from the SObject specified in {@link #table}.
     *
     * @param fieldName The API name of the field to add to the query's SELECT clause.
     **/
    public QueryFactory selectField(String fieldName)
    {
        fields.add( getFieldToken(fieldName) );
        return this;
    }

    /**
     * Selects a field, avoiding the possible ambiguitiy of String API names.
     * @see #selectField(String)
     *
     * @param field the {@link SObjectField} to select with this query.
     * @exception InvalidFieldException If the field is null {@code field}.
     **/
    public QueryFactory selectField(SObjectField field)
    {
        if (field == null)
        {
            throw new InvalidFieldException(null,this.table);
        }

        if (enforceFLS)
        {
            SecurityUtils.checkFieldIsReadable(table, field);
        }

        fields.add(new QueryField(field));

        return this;
    }

    /**
     * Selects multiple fields. This acts the same as calling {@link #selectField(String)} multiple times.
     *
     * @param fieldNames the Set of field API names to select.
     **/
    public QueryFactory selectFields(Set<String> fieldNames)
    {
        List<String> fieldList = new List<String>();
        Set<QueryField> toAdd = new Set<QueryField>();

        for (String fieldName:fieldNames)
        {
            toAdd.add(getFieldToken(fieldName));
        }

        fields.addAll(toAdd);

        return this;
    }

    /**
     * Selects multiple fields. This acts the same as calling {@link #selectField(String)} multiple times.
     *
     * @param fieldNames the List of field API names to select.
     **/
    public QueryFactory selectFields(List<String> fieldNames)
    {
        Set<QueryField> toAdd = new Set<QueryField>();

        for (String fieldName:fieldNames)
        {
            toAdd.add(getFieldToken(fieldName));
        }

        fields.addAll(toAdd);

        return this;
    }

    /**
     * Selects multiple fields. This acts the same as calling {@link #selectField(SObjectField)} multiple times.
     *
     * @param fieldNames the set of {@link SObjectField}s to select.
     * @exception InvalidFieldException if the fields are null {@code fields}.
     **/
    public QueryFactory selectFields(Set<SObjectField> fields)
    {
        for (SObjectField token:fields)
        {
            if (token == null)
            {
                throw new InvalidFieldException();
            }

            if (enforceFLS)
            {
                SecurityUtils.checkFieldIsReadable(table, token);
            }

            this.fields.add( new QueryField(token) );
        }
        return this;
    }

    /**
     * Selects multiple fields. This acts the same as calling {@link #selectField(SObjectField)} multiple times.
     *
     * @param fieldNames the set of {@link SObjectField}s to select.
     * @exception InvalidFieldException if the fields are null {@code fields}.
     **/
    public QueryFactory selectFields(List<SObjectField> fields)
    {
        for (SObjectField token:fields)
        {
            if (token == null)
            {
                throw new InvalidFieldException();
            }

            if (enforceFLS)
            {
                SecurityUtils.checkFieldIsReadable(table, token);
            }

            this.fields.add(new QueryField(token));
        }
        return this;
    }

    /**
     * @see #selectFieldSet(FieldSet,Boolean)
     **/
    public QueryFactory selectFieldSet(Schema.FieldSet fieldSet)
    {
        return selectFieldSet(fieldSet,true);
    }

    /**
     * This is equivielent to iterating the fields in the field set and calling {@link #selectField(String)} on each.
     *
     * @param fieldSet Select all fields included in the field set.
     * @param allowCrossObject if false this method will throw an exception if any fields in the field set reference fields on a related record.
     * @exception InvalidFieldSetException if the fieldset is invalid for table {@code fields}.
     **/
    public QueryFactory selectFieldSet(Schema.FieldSet fieldSet, Boolean allowCrossObject)
    {
        if (fieldSet.getSObjectType() != table)
        {
            throw new InvalidFieldSetException('Field set "'+fieldSet.getName()+'" is not for SObject type "'+table+'"');
        }

        for (Schema.FieldSetMember field: fieldSet.getFields())
        {
            if (!allowCrossObject && field.getFieldPath().contains('.'))
            {
                throw new InvalidFieldSetException('Cross-object fields not allowed and field "'+field.getFieldPath()+'"" is a cross-object field.');
            }

            fields.add( getFieldToken(field.getFieldPath()) );
        }

        return this;
    }

    /**
     * Adds a where condition to the select query
     *
     * @param conditionExpression Sets the WHERE clause to the string provided. Do not include the "WHERE".
     **/
    public QueryFactory setCondition(String conditionExpression)
    {
        this.conditionExpression = conditionExpression;
        return this;
    }

    /**
     * Get the conditional from the select query
     *
     * @return The current value of the WHERE clause, if any, as set by {@link #setCondition}
     **/
    public String getCondition()
    {
        return this.conditionExpression;
    }

    /**
     * Adds a limit qualifier to the query
     *
     * @param limitCount if not null causes a LIMIT caluse to be added to the resulting query.
     **/
    public QueryFactory setLimit(Integer limitCount)
    {
        this.limitCount = limitCount;
        return this;
    }

    /**
     * Get the limit qualifier for the query
     *
     * @return The current value of the LIMIT clause, if any.
     **/
    public Integer getLimit()
    {
        return this.limitCount;
    }

    /**
     * Add an order by clause to the query
     *
     * @param o an instance of {@link QueryFactory.Ordering} to be added to the query's ORDER BY clause.
     **/
    public QueryFactory addOrdering(Ordering o)
    {
        this.order.add(o);
        return this;
    }

    /**
     * Get the order by clauses from the query.
     *
     * @return The list of orderings that will be used as the query's ORDER BY clause.
     **/
    public List<Ordering> getOrderings()
    {
        return this.order;
    }

    /**
     * Get the selected fields from the query.
     *
     * @return The selected fields
     **/
    public Set<QueryField> getSelectedFields()
    {
        return this.fields;
    }

    /**
     * Add a subquery query to this query.  If a subquery for this relationshipName already exists, it will be returned.
     * If not, a new one will be created and returned.
     *
     * @exception InvalidSubqueryRelationshipException If this method is called on a subselectQuery or with an invalid relationship
     * @param relationshipName The relationshipName to be added as a subquery
     **/
    public QueryFactory subselectQuery(String relationshipName)
    {
        return subselectQuery(relationshipName, false);
    }

    /**
     * Add a subquery query to this query.  If a subquery for this relationship already exists, it will be returned.
     * If not, a new one will be created and returned.
     *
     * @exception InvalidSubqueryRelationshipException If this method is called on a subselectQuery or with an invalid relationship
     * @param relationshipName The relationshipName to be added as a subquery
     * @param assertIsAccessible indicates whether to check if the user has access to the subquery object
     **/
    public QueryFactory subselectQuery(String relationshipName, Boolean assertIsAccessible)
    {
        ChildRelationship relationship = getChildRelationship(relationshipName);

        if (relationship != null)
        {
            return setSubselectQuery(relationship, assertIsAccessible);
        }

        throw new InvalidSubqueryRelationshipException('Invalid call to subselectQuery with relationshipName = '+relationshipName +'.  Relationship does not exist for ' + table.getDescribe().getName());
    }

    /**
     * Add a subquery query to this query.  If a subquery for this relationshipName already exists, it will be returned.
     * If not, a new one will be created and returned.
     *
     * @exception InvalidSubqueryRelationshipException If this method is called on a subselectQuery or with an invalid relationship
     * @param relationship The ChildRelationship to be added as a subquery
     **/
    public QueryFactory subselectQuery(ChildRelationship relationship)
    {
        return subselectQuery(relationship, false);
    }

    /**
     * Add a subquery query to this query.  If a subquery for this relationship already exists, it will be returned.
     * If not, a new one will be created and returned.
     *
     * @exception InvalidSubqueryRelationshipException If this method is called on a subselectQuery or with an invalid relationship
     * @param relationship The ChildRelationship to be added as a subquery
     * @param assertIsAccessible indicates whether to check if the user has access to the subquery object
     **/
    public QueryFactory subselectQuery(ChildRelationship relationship, Boolean assertIsAccessible)
    {
        return setSubselectQuery(relationship, assertIsAccessible);
    }

    /**
     * Add a subquery query to this query.  If a subquery for this relationship already exists, it will be returned.
     * If not, a new one will be created and returned.
     *
     * @exception InvalidSubqueryRelationshipException If this method is called on a subselectQuery or with an invalid relationship
     * @param relationship The ChildRelationship to be added as a subquery
     **/
    private QueryFactory setSubselectQuery(ChildRelationship relationship, Boolean assertIsAccessible)
    {
        if (this.relationship != null)
        {
            throw new InvalidSubqueryRelationshipException('Invalid call to subselectQuery.  You may not add a subselect query to a subselect query.');
        }

        if (this.subselectQueryMap == null)
        {
            this.subselectQueryMap = new Map<ChildRelationship, QueryFactory>();
        }

        if (this.subselectQueryMap.containsKey(relationship))
        {
            return subselectQueryMap.get(relationship);
        }

        QueryFactory subselectQuery = new QueryFactory(relationship);

        //The child queryFactory should be configured in the same way as the parent by default - can override after if required
        subSelectQuery.setSortSelectFields(sortSelectFields);

        if (assertIsAccessible){
            subSelectQuery.assertIsAccessible();
        }

        subselectQueryMap.put(relationship, subSelectQuery);

        return subSelectQuery;
    }

    /**
     * @returns the list of subquery instances of QueryFactory which will be added to the SOQL as relationship/child/sub-queries.
     **/
    public List<QueryFactory> getSubselectQueries()
    {
        if (subselectQueryMap != null)
        {
            return subselectQueryMap.values();
        }

        return null;
    }

    /**
     * Get the ChildRelationship from the Table for the object type passed in.
     *
     * @param objType The object type of the child relationship to get
     **/
    private Schema.ChildRelationship getChildRelationship(sObjectType objType)
    {
        for (Schema.ChildRelationship childRow : table.getDescribe().getChildRelationships())
        {
            //occasionally on some standard objects (Like Contact child of Contact) do not have a relationship name.
            //if there is no relationship name, we cannot query on it, so throw an exception.
            if (childRow.getChildSObject() == objType && childRow.getRelationshipName() != null)
            {
                return childRow;
            }
        }

        throw new InvalidSubqueryRelationshipException('Invalid call to subselectQuery.  Invalid relationship for table '+table + ' and objtype='+objType);
    }

    /**
     * Get the ChildRelationship from the Table for the relationship name passed in.
     *
     * @param relationshipName The name of the object's ChildRelationship on get
     **/
    private Schema.ChildRelationship getChildRelationship(String relationshipName)
    {
        for (Schema.ChildRelationship childRow : table.getDescribe().getChildRelationships())
        {
            if (childRow.getRelationshipName() == relationshipName)
            {
                return childRow;
            }
        }
        return null;
    }

    /**
     * Add a field to be sorted on.  This may be a direct field or a field
     * related through an object lookup or master-detail relationship.
     * Use the set to store unique field names, since we only want to sort
     * by the same field one time.  The sort expressions are stored in a list
     * so that they are applied to the SOQL in the same order that they
     * were added in.
     *
     * @param fieldName The string value of the field to be sorted on
     * @param SortOrder the direction to be sorted on (ASCENDING or DESCENDING)
     * @param nullsLast whether to sort null values last (NULLS LAST keyword included).
     **/
    public QueryFactory addOrdering(String fieldName, SortOrder direction, Boolean nullsLast)
    {
        order.add(
            new Ordering(getFieldToken(fieldName), direction, nullsLast)
        );
        return this;
    }

     /**
     * Add a field to be sorted on.  This may be a direct field or a field
     * related through an object lookup or master-detail relationship.
     * Use the set to store unique field names, since we only want to sort
     * by the same field one time.  The sort expressions are stored in a list
     * so that they are applied to the SOQL in the same order that they
     * were added in.
     *
     * @param field The SObjectfield to sort.  This can only be a direct reference.
     * @param SortOrder the direction to be sorted on (ASCENDING or DESCENDING)
     * @param nullsLast whether to sort null values last (NULLS LAST keyword included).
     **/
    public QueryFactory addOrdering(SObjectField field, SortOrder direction, Boolean nullsLast)
    {
        order.add(
            new Ordering(new QueryField(field), direction, nullsLast)
        );
        return this;
    }

    /**
     * Add a field to be sorted on.  This may be a direct field or a field
     * related through an object lookup or master-detail relationship.
     * Use the set to store unique field names, since we only want to sort
     * by the same field one time.  The sort expressions are stored in a list
     * so that they are applied to the SOQL in the same order that they
     * were added in.
     * The "NULLS FIRST" keywords will be included by default.  If "NULLS LAST"
     * is required, use one of the overloaded addOrdering methods which include this parameter.
     *
     * @param fieldName The string value of the field to be sorted on
     * @param SortOrder the direction to be sorted on (ASCENDING or DESCENDING)
     **/
    public QueryFactory addOrdering(String fieldName, SortOrder direction)
    {
        order.add(
            new Ordering(getFieldToken(fieldName), direction)
        );
        return this;
    }

     /**
     * Add a field to be sorted on.  This may be a direct field or a field
     * related through an object lookup or master-detail relationship.
     * Use the set to store unique field names, since we only want to sort
     * by the same field one time.  The sort expressions are stored in a list
     * so that they are applied to the SOQL in the same order that they
     * were added in.
     * The "NULLS FIRST" keywords will be included by default.  If "NULLS LAST"
     * is required, use one of the overloaded addOrdering methods which include this parameter.
     *
     * @param field The SObjectfield to sort.  This can only be a direct reference.
     * @param SortOrder the direction to be sorted on (ASCENDING or DESCENDING)
     **/
    public QueryFactory addOrdering(SObjectField field, SortOrder direction)
    {
        order.add(
            new Ordering(new QueryField(field), direction)
        );
        return this;
    }

    /**
     * Convert the values provided to this instance into a full SOQL string for use with Database.query
     * Check to see if subqueries queries need to be added after the field list.
     **/
    public String toSOQL()
    {
        String result = 'SELECT ';
        //if no fields have been added, just add the Id field so that the query or subquery will not just fail
        if (fields.isEmpty())
        {
            if (enforceFLS)
            {
                SecurityUtils.checkFieldIsReadable(table, 'Id');
            }

            result += 'Id  ';
        }
        else if (sortSelectFields)
        {
            List<QueryField> fieldsToQuery = new List<QueryField>(fields);
            fieldsToQuery.sort(); //delegates to QueryFilter's comparable implementation
            for (QueryField field:fieldsToQuery)
            {
                result += field + ', ';
            }
        }
        else
        {
            for (QueryField field : fields)
            {
                result += field + ', ';
            }
        }

        if (subselectQueryMap != null && !subselectQueryMap.isEmpty())
        {
            for (QueryFactory childRow : subselectQueryMap.values())
            {
                result += ' (' + childRow.toSOQL() + '), ';
            }
        }
        result = result.substring(0,result.length()-2) + ' FROM ' + (relationship != null ? relationship.getRelationshipName() : table.getDescribe().getName());
        if (!String.isBlank(conditionExpression))
        {
            result += ' WHERE ' + conditionExpression;
        }

        if (order.size() > 0)
        {
            result += ' ORDER BY ';
            for (Ordering o : order)
            {
                result += o.toSOQL() + ', ';
            }

            result = result.substring(0,result.length()-2);
        }

        if (limitCount != null)
        {
            result += ' LIMIT ' + limitCount;
        }

        return result;
    }

    public QueryFactory deepClone()
    {
        QueryFactory clone = new QueryFactory(this.table)
            .setLimit(this.limitCount)
            .setCondition(this.conditionExpression)
            .setEnforceFLS(this.enforceFLS);

        Map<Schema.ChildRelationship, QueryFactory> subqueries = this.subselectQueryMap;
        if (subqueries != null)
        {
            Map<Schema.ChildRelationship, QueryFactory> clonedSubqueries = new Map<Schema.ChildRelationship, QueryFactory>();
            for (Schema.ChildRelationship key : subqueries.keySet())
            {
                clonedSubqueries.put(key, subqueries.get(key).deepClone());
            }
            clone.subselectQueryMap = clonedSubqueries;
        }

        clone.relationship = this.relationship;
        clone.order = this.order.clone();
        clone.fields = this.fields.clone();

        return clone;
    }

    public class Ordering
    {
        private SortOrder direction;
        private boolean nullsLast;
        private QueryField field;

        public Ordering(String sobjType, String fieldName, SortOrder direction)
        {
            this(
                fflib_SObjectDescribe.getDescribe(sobjType).getField(fieldName),
                direction
            );
        }

        public Ordering(SObjectField field, SortOrder direction)
        {
            this(field, direction, false); //SOQL docs state NULLS FIRST is default behavior
        }

        public Ordering(SObjectField field, SortOrder direction, Boolean nullsLast)
        {
            this(new QueryField(field), direction, nullsLast);
        }

        private Ordering(QueryField field, SortOrder direction)
        {
            this(field, direction, false);
        }

        private Ordering(QueryField field, SortOrder direction, Boolean nullsLast)
        {
            this.direction = direction;
            this.field = field;
            this.nullsLast = nullsLast;
        }

        public List<SObjectField> getFields()
        {
            return this.field.getFieldPath();
        }

        public SortOrder getDirection()
        {
            return direction;
        }

        public String toSOQL()
        {
            return field + ' ' + (direction == SortOrder.ASCENDING ? 'ASC' : 'DESC') + (nullsLast ? ' NULLS LAST ' : ' NULLS FIRST ');
        }
    }


    public class QueryField implements Comparable
    {
        List<SObjectField> fields;

        /**
         * The first field in the path to to field being queried
         **/
        public SObjectField getBaseField()
        {
            return fields[0];
        }

        /**
         * The full list of fields representing the path to the field being queried
         **/
        public List<SObjectField> getFieldPath()
        {
            return fields.clone();
        }

        private QueryField(List<SObjectField> fields)
        {
            if (fields == null || fields.isEmpty())
            {
                throw new InvalidFieldException('Invalid field: null');
            }

            this.fields = fields.clone(); //don't let clients mutate after setting!
        }

        private QueryField(SObjectField field)
        {
            if (field == null)
            {
                throw new InvalidFieldException('Invalid field: null');
            }

            fields = new List<SObjectField>{ field };
        }

        public override String toString()
        {
            String result = '';
            Integer size = fields.size();

            for (Integer i=0; i<size; i++)
            {
                if (i>0)
                {
                    if (result.endsWithIgnoreCase('Id'))
                    {
                        result = result.removeEndIgnoreCase('Id');
                    }
                    else if (result.endsWithIgnoreCase('__c'))
                    {
                        result = result.removeEndIgnoreCase('__c') + '__r';
                    }

                    result += '.';
                }

                result += fields[i].getDescribe().getName();
            }

            return result;
        }

        public integer hashCode()
        {
            return String.valueOf(this.fields).hashCode();
        }

        public boolean equals(Object obj)
        {
            //Easy checks first
            if (obj == null || !(obj instanceof QueryField))
            {
                return false;
            }

            if (this === obj)
            {
                return true;
            }

            //Detailed checks
            QueryField other = (QueryField)obj;
            Integer size = fields.size();
            if (size != other.fields.size())
            {
                return false;
            }

            for (Integer i = 0; i < size; i++)
            {
                if (fields[i] != (other.fields[i]))
                {
                    return false;
                }
            }

            return true;
        }

        /**
         * Allows sorting QueryField instances.
         *
         * Returns
         * - Objects that are not QueryField instances as -2, which functions as -1 but with more flair
         * - Equivalent QueryFields return 0.
         * - QueryFields with more joins give +1, while fewer joins give -1
         * - For anything else, compare the toStrings of this and the supplied object.
         **/
        public Integer compareTo(Object o)
        {
            if (o == null || !(o instanceof QueryField))
            {
                return -2; //We can't possibly do a sane comparison against an unknwon type, go athead and let it "win"
            }

            if (this === o)
            {
                return 0;
            }

            QueryField other = (QueryField)o;
            Integer size = fields.size();
            Integer sizeOther = other.fields.size();

            if (size < sizeOther)
            {
                return -1;
            }

            if (size > sizeOther)
            {
                return 1;
            }

            return this.toString().compareTo(other.toString());
        }
    }

    public class InvalidFieldException extends Exception
    {
        private String fieldName;
        private Schema.SObjectType objectType;

        public InvalidFieldException(String fieldname, Schema.SObjectType objectType)
        {
            this.objectType = objectType;
            this.fieldName = fieldName;
            this.setMessage( 'Invalid field \''+fieldName+'\' for object \''+objectType+'\'' );
        }
    }

    public class InvalidFieldSetException extends Exception
    {

    }

    public class NonReferenceFieldException extends Exception
    {

    }

    public class InvalidSubqueryRelationshipException extends Exception
    {

    }
}