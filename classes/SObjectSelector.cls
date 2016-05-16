public abstract with sharing class SObjectSelector
{
    public class SelectorException extends exception
    {

    }

    /**
     * This overrides the Multi Currency handling, preventing it from injecting the CurrencyIsoCode
     *  field for certain System objects that don't ever support it
     **/
    private static Set<String> STANDARD_WITHOUT_CURRENCYISO = new Set<String>
    {
        'ApexClass',
        'ApexTrigger',
        'AsyncApexJob',
        'Attachment',
        'RecordType'
    };

    /**
     * Should this selector automatically include the FieldSet fields when building queries?
     **/
    private Boolean includeFieldSetFields;

    /**
     * Enforce FLS Security
     **/
    private Boolean enforceFLS;

    /**
     * Enforce CRUD Security
     **/
    private Boolean enforceCRUD;

    /**
     * Order by field
     **/
    private String orderBy;

    /**
     * Sort the query fields in the select statement (defaults to true, at the expense of performance).
     * Switch this off if you need more performant queries.
     **/
    private Boolean sortSelectFields;

    /**
     * Describe helper
     **/
    private DescribeWrapper describeWrapper
    {
        get
        {
            if(describeWrapper == null)
            {
                describeWrapper = DescribeWrapper.getDescribe(getSObjectType());
            }

            return describeWrapper;
        }
        set;
    }

    /**
     * Implement this method to inform the base class of the SObject (custom or standard) to be queried
     **/
    abstract SObjectType getSObjectType();

    /**
     * Implement this method to inform the base class of the common fields to be queried or listed by the base class methods
     **/
    abstract List<SObjectField> getSObjectFieldList();

    /**
     * Constructs the Selector, defaults to not including any FieldSet fields automatically
     **/
    public SObjectSelector()
    {
        this(false);
    }

    /**
     * Constructs the Selector
     *
     * @param includeFieldSetFields Set to true if the Selector queries are to include Fieldset fields as well
     **/
    public SObjectSelector(Boolean includeFieldSetFields)
    {
        this(includeFieldSetFields, true, false);
    }

    /**
     * Constructs the Selector
     *
     * @param includeFieldSetFields Set to true if the Selector queries are to include Fieldset fields as well
     **/
    public SObjectSelector(Boolean includeFieldSetFields, Boolean enforceCRUD, Boolean enforceFLS)
    {
        this(includeFieldSetFields, enforceCRUD, enforceFLS, true);
    }

    /**
     * Constructs the Selector
     *
     * @param includeFieldSetFields Set to true if the Selector queries are to include Fieldset fields as well
     * @param enforceCRUD Enforce CRUD security
     * @param enforeFLS Enforce Field Level Security
     * @param sortSelectFields Set to false if selecting many columns to skip sorting select fields and improve performance
     **/
    public SObjectSelector(Boolean includeFieldSetFields, Boolean enforceCRUD, Boolean enforceFLS, Boolean sortSelectFields)
    {
        this.includeFieldSetFields = includeFieldSetFields;
        this.enforceCRUD = enforceCRUD;
        this.enforceFLS = enforceFLS;
        this.sortSelectFields = sortSelectFields;
    }

    /**
     * Override this method to provide a list of Fieldsets that can optionally drive inclusion of additional fields in the base queries
     **/
    public virtual List<FieldSet> getSObjectFieldSetList()
    {
        return null;
    }

    /**
     * Override this method to control the default ordering of records returned by the base queries,
     * defaults to the name field of the object or CreatedDate if there is none
     **/
    public virtual String getOrderBy()
    {
        if(orderBy == null)
        {
            orderBy = 'CreatedDate';
            if(describeWrapper.getNameField() != null)
            {
                orderBy = describeWrapper.getNameField().getDescribe().getName();
            }
        }

        return orderBy;
    }

    /**
     * Returns True if this Selector instance has been instructed by the caller to include Field Set fields
     **/
    public Boolean isIncludeFieldSetFields()
    {
        return includeFieldSetFields;
    }

    /**
     * Returns True if this Selector is enforcing FLS
     **/
    public Boolean isEnforcingFLS()
    {
        return enforceFLS;
    }

    /**
     * Returns True if this Selector is enforcing CRUD Security
     **/
    public Boolean isEnforcingCRUD()
    {
        return enforceCRUD;
    }

    /**
     * Provides access to the builder containing the list of fields base queries are using, this is demand
     *   created if one has not already been defined via setFieldListBuilder
     *
     * @depricated See newQueryFactory
     **/
    public fflib_StringBuilder.FieldListBuilder getFieldListBuilder()
    {
        List<SObjectField> sObjectFields = new List<SObjectField>();

        for (QueryFactory.QueryField queryField : newQueryFactory().getSelectedFields())
        {
            sObjectFields.add(queryField.getBaseField());
        }

        return new fflib_StringBuilder.FieldListBuilder(sObjectFields);
    }

    /**
     * Use this method to override the default FieldListBuilder (created on demand via getFieldListBuilder) with a custom one,
     *   warning, this will bypass anything getSObjectFieldList or getSObjectFieldSetList returns
     *
     * @depricated See newQueryFactory
     **/
    public void setFieldListBuilder(fflib_StringBuilder.FieldListBuilder fieldListBuilder)
    {
        // TODO: Consider if given the known use cases for this (dynamic selector optomisation) if it's OK to leave this as a null operation
    }

    /**
     * Returns in string form a comma delimted list of fields as defined via getSObjectFieldList and optionally getSObjectFieldSetList
     *
     * @depricated See newQueryFactory
     **/
    public String getFieldListString()
    {
        return getFieldListBuilder().getStringValue();
    }

    /**
     * Returns in string form a comma delimted list of fields as defined via getSObjectFieldList and optionally getSObjectFieldSetList
     * @param relation Will prefix fields with the given relation, e.g. MyLookupField__r
     *
     * @depricated See newQueryFactory
     **/
    public String getRelatedFieldListString(String relation)
    {
        return getFieldListBuilder().getStringValue(relation + '.');
    }

    /**
     * Returns the string representaiton of the SObject this selector represents
     **/
    public String getSObjectName()
    {
        return describeWrapper.getDescribe().getName();
    }

    /**
     * Performs a SOQL query,
     *   - Selecting the fields described via getSObjectFieldsList and getSObjectFieldSetList (if included)
     *   - From the SObject described by getSObjectType
     *   - Where the Id's match those provided in the set
     *   - Ordered by the fields returned via getOrderBy
     * @returns A list of SObject's
     **/
    public List<SObject> selectSObjectsById(Set<Id> idSet)
    {
        return Database.query(buildQuerySObjectById());
    }

    /**
     * Performs a SOQL query,
     *   - Selecting the fields described via getSObjectFieldsList and getSObjectFieldSetList (if included)
     *   - From the SObject described by getSObjectType
     *   - Where the Id's match those provided in the set
     *   - Ordered by the fields returned via getOrderBy
     * @returns A QueryLocator (typically for use in a Batch Apex job)
     **/
    public Database.QueryLocator queryLocatorById(Set<Id> idSet)
    {
        return Database.getQueryLocator(buildQuerySObjectById());
    }

    /**
     * Throws an exception if the SObject indicated by getSObjectType is not accessible to the current user (read access)
     *
     * @depricated If you utilise the newQueryFactory method this is automatically done for you (unless disabled by the selector)
     **/
    public void assertIsAccessible()
    {
        if(!getSObjectType().getDescribe().isAccessible())
        {
           throw new SelectorException(
                'Permission to access an ' + getSObjectType().getDescribe().getName() + ' denied.');
        }
    }

    /**
     * Public acccess for the getSObjectType during Mock registration
     *   (adding public to the existing method broken base class API backwards compatability)
     **/
    public SObjectType getSObjectType2()
    {
        return getSObjectType();
    }

    /**
     * Public acccess for the getSObjectType during Mock registration
     *   (adding public to the existing method broken base class API backwards compatability)
     **/
    public SObjectType sObjectType()
    {
        return getSObjectType();
    }

    /**
     * Returns a QueryFactory configured with the Selectors object, fields, fieldsets and default order by
     **/
    public QueryFactory newQueryFactory()
    {
        return newQueryFactory(enforceCRUD, enforceFLS, true);
    }

    /**
     * Returns a QueryFactory configured with the Selectors object, fields, fieldsets and default order by
     **/
    public QueryFactory newQueryFactory(Boolean includeSelectorFields)
    {
        return newQueryFactory(enforceCRUD, enforceFLS, includeSelectorFields);
    }

    /**
     * Returns a QueryFactory configured with the Selectors object, fields, fieldsets and default order by
     * CRUD and FLS read security will be checked if the corresponding inputs are true (overrides that defined in the selector).
     **/
    public QueryFactory newQueryFactory(Boolean assertCRUD, Boolean enforceFLS, Boolean includeSelectorFields)
    {
        // Construct QueryFactory around the given SObject
        return configureQueryFactory(
            new QueryFactory(getSObjectType2()),
                assertCRUD, enforceFLS, includeSelectorFields);
    }

    /**
     * Adds the selectors fields to the given QueryFactory using the given relationship path as a prefix
     *
     * // TODO: This should be consistant (ideally) with configureQueryFactory below
     **/
    public void configureQueryFactoryFields(QueryFactory queryFactory, String relationshipFieldPath)
    {
        // Add fields from selector prefixing the relationship path
        for (SObjectField field : getSObjectFieldList())
        {
            queryFactory.selectField(relationshipFieldPath + '.' + field.getDescribe().getName());
        }
        // Automatically select the CurrencyIsoCode for MC orgs (unless the object is a known exception to the rule)
        if(Userinfo.isMultiCurrencyOrganization() &&
           !STANDARD_WITHOUT_CURRENCYISO.contains(getSObjectType().getDescribe().getName()))
        {
            queryFactory.selectField(relationshipFieldPath+'.CurrencyIsoCode');
        }
    }

    /**
     * Adds a subselect QueryFactory based on this selector to the given QueryFactor, returns the parentQueryFactory
     **/
    public QueryFactory addQueryFactorySubselect(QueryFactory parentQueryFactory)
    {
        return addQueryFactorySubselect(parentQueryFactory, true);
    }

    /**
     * Adds a subselect QueryFactory based on this selector to the given QueryFactor
     **/
    public QueryFactory addQueryFactorySubselect(QueryFactory parentQueryFactory, Boolean includeSelectorFields)
    {
        QueryFactory subSelectQueryFactory =
            parentQueryFactory.subselectQuery(getSObjectType2());

        return configureQueryFactory(
            subSelectQueryFactory,
            enforceCRUD,
            enforceFLS,
            includeSelectorFields);
    }

    /**
     * Constructs the default SOQL query for this selector, see selectSObjectsById and queryLocatorById
     **/
    private String buildQuerySObjectById()
    {
        return newQueryFactory().setCondition('id in :idSet').toSOQL();
    }

    /**
     * Configures a QueryFactory instance according to the configuration of this selector
     **/
    private QueryFactory configureQueryFactory(QueryFactory queryFactory, Boolean assertCRUD, Boolean enforceFLS, Boolean includeSelectorFields)
    {
        // CRUD and FLS security required?
        if (assertCRUD)
        {
            try
            {
                // Leverage QueryFactory for CRUD checking
                queryFactory.assertIsAccessible();
            }
            catch (SecurityUtils.CrudException e)
            {
                // Marshal exception into DomainException for backwards compatability
                throw new SelectorException(
                    'Permission to access an ' + getSObjectType().getDescribe().getName() + ' denied.');
            }
        }
        queryFactory.setEnforceFLS(enforceFLS);

        // Configure the QueryFactory with the Selector fields?
        if(includeSelectorFields)
        {
            // select the Selector fields and Fieldsets and set order
            queryFactory.selectFields(getSObjectFieldList());

            List<FieldSet> fieldSetList = getSObjectFieldSetList();
            if(includeFieldSetFields && fieldSetList != null)
            {
                for (FieldSet fieldSet : fieldSetList)
                {
                    queryFactory.selectFieldSet(fieldSet);
                }
            }

            // Automatically select the CurrencyIsoCode for MC orgs (unless the object is a known exception to the rule)
            if(Userinfo.isMultiCurrencyOrganization() &&
               !STANDARD_WITHOUT_CURRENCYISO.contains(getSObjectType().getDescribe().getName()))
            {
                queryFactory.selectField('CurrencyIsoCode');
            }
        }

        // Parse the getOrderBy()
        for (String orderBy : getOrderBy().split(','))
        {
            // TODO: Handle NULLS FIRST and NULLS LAST, http://www.salesforce.com/us/developer/docs/soql_sosl/Content/sforce_api_calls_soql_select_orderby.htm
            List<String> orderByParts = orderBy.trim().split(' ');
            String fieldNamePart = orderByParts[0];
            String fieldSortOrderPart = orderByParts.size() > 1 ? orderByParts[1] : null;
            QueryFactory.SortOrder fieldSortOrder = QueryFactory.SortOrder.ASCENDING;
            if(fieldSortOrderPart==null)
            {
                fieldSortOrder = QueryFactory.SortOrder.ASCENDING;
            }
            else if(fieldSortOrderPart.equalsIgnoreCase('DESC'))
            {
                fieldSortOrder = QueryFactory.SortOrder.DESCENDING;
            }
            else if(fieldSortOrderPart.equalsIgnoreCase('ASC'))
            {
                fieldSortOrder = QueryFactory.SortOrder.ASCENDING;
            }

            queryFactory.addOrdering(fieldNamePart, fieldSortOrder);
        }

        queryFactory.setSortSelectFields(sortSelectFields);

        return queryFactory;
    }
}