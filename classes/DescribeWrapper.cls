public class DescribeWrapper
{
    //internal implementation details
    private SObjectType token;
    private SObjectField nameField;
    private DescribeSObjectResult describe
    { //lazy load - keep this leightweight until we need more data
        get
        {
            if (describe == null)
            {
                describe = token.getDescribe();
            }

            return describe;
        }
        set;
    }

    private Map<String,SObjectField> fields
    {
        get
        {
            if (fields == null)
            {
                fields = describe.fields.getMap();
            }

            return fields;
        }
        set;
    }
    private Map<String,FieldSet> fieldSets
    {
        get
        {
            if (fieldSets == null)
            {
                fieldSets = describe.fieldSets.getMap();
            }

            return fieldSets;
        }
        set;
    }
    private FieldsMap wrappedFields
    {
        get
        {
            if (wrappedFields == null)
            {
                wrappedFields = new FieldsMap(this.fields);
            }

            return wrappedFields;
        }
        set;
    }

    private DescribeWrapper(SObjectType token)
    {
        if (token == null)
        {
            throw new InvalidDescribeException('Invalid SObject type: null');
        }

        if (instanceCache.containsKey(String.valueOf(token)))
        {
            throw new DuplicateDescribeException(token + ' is already in the describe cache');
        }

        this.token = token;
        instanceCache.put( String.valueOf(token).toLowerCase() , this);
    }

    //public instace methods
    /**
     * Returns the SObjectType this DescribeWrapper instance is based on.
    **/
    public SObjectType getSObjectType()
    {
        return token;
    }

    /**
     * This method is a convenient shorthand for calling getField(name, true)
    **/
    public SObjectField getField(String name)
    {
        return this.getField(name, true);
    }

    /**
     * This method provides a simplified shorthand for calling #getFields and getting the provided field.
     * Additionally it handles finding the correct SObjectField for relationship notation,
     * e.g. getting the Account field on Contact would fail without being referenced as AccountId - both work here.
    **/
    public SObjectField getField(String fieldName, Boolean implyNamespace)
    {
        SObjectField result = wrappedFields.get(
            (fieldName.endsWithIgnoreCase('__r') ? //resolve custom field cross-object (__r) syntax
            (fieldName.removeEndIgnoreCase('__r')+'__c') :
            fieldName),
            implyNamespace
        );

        if (result == null)
        {
            result = wrappedFields.get(fieldName+'Id', implyNamespace); //in case it's a standard lookup in cross-object format
        }

        return result;
    }

    /**
    * Returns the field where isNameField() is true (if any); otherwise returns null
    **/
    public SObjectField getNameField()
    {
        if (nameField == null)
        {
            for (SObjectField field : wrappedFields.values())
            {
                if (field.getDescribe().isNameField())
                {
                    nameField = field;
                    break;
                }
            }
        }

        return nameField;
    }

    /**
     * Returns the raw DescribeSObjectResult an DescribeWrapper instance wraps.
    **/
    public DescribeSObjectResult getDescribe()
    {
        return describe;
    }
    /**
     * This method returns the raw data and provides no namespace handling.
     * Due to this, __use of this method is discouraged__ in favor of getFields().
    **/
    public Map<String,SObjectField> getFieldsMap()
    {
        return fields;
    }

    public FieldsMap getFields()
    {
        return wrappedFields;
    }

    public Map<String,FieldSet> getFieldSetsMap()
    {
        return fieldSets;
    }

    private static Map<String,SObjectType> rawGlobalDescribe
    {
        get
        {
            if (rawGlobalDescribe == null)
            {
                rawGlobalDescribe = getGlobalDescribe();
            }

            return rawGlobalDescribe;
        }
        set;
    }

    private static GlobalDescribeMap wrappedGlobalDescribe
    {
        get
        {
            if (wrappedGlobalDescribe == null)
            {
                wrappedGlobalDescribe = new GlobalDescribeMap(rawGlobalDescribe);
            }

            return wrappedGlobalDescribe;
        }
        set;
    }
    /**
     * This is used to cache DescribeWrapper instances as they're consutrcted
     * to prevent repeatedly re-constructing the same type.
     * These instances are not guaranteed to be, but typically will be, unique per sObject type due to the presence of flushCache.
    **/
    private static Map<String,DescribeWrapper> instanceCache
    {
        get
        {
            if (instanceCache == null)
            {
                instanceCache = new Map<String,DescribeWrapper>();
            }

            return instanceCache;
        }
        set;
    }
    public static DescribeWrapper getDescribe(String sObjectName)
    {
        if (String.isBlank(sObjectName))
        {
            return null;
        }

        DescribeWrapper result = instanceCache.get(sObjectName.toLowerCase());
        if (result == null)
        {
            SObjectType token = wrappedGlobalDescribe.get(sObjectName.toLowerCase());
            if (token == null)
            {
                result = null;
            }
            else
            {
                result = new DescribeWrapper(token);
            }
        }

        return result;
    }
    public static DescribeWrapper getDescribe(SObjectType token)
    {
        if (token == null)
        {
            return null;
        }

        DescribeWrapper result = instanceCache.get(String.valueOf(token).toLowerCase());
        if (result == null)
        {
            result = new DescribeWrapper(token);
        }

        return result;
    }
    public static DescribeWrapper getDescribe(DescribeSObjectResult nativeDescribe)
    {
        if (nativeDescribe == null)
        {
            return null;
        }

        DescribeWrapper result = instanceCache.get(nativeDescribe.getName().toLowerCase());
        if (result == null)
        {
            result = new DescribeWrapper(nativeDescribe.getSobjectType());
        }

        return result;
    }

    public static DescribeWrapper getDescribe(SObject instance)
    {
        if (instance == null)
        {
            return null;
        }

        return getDescribe(instance.getSobjectType());
    }

    //returns the same results as the native method, just with caching built in to avoid limits
    public static Map<String,SObjectType> getRawGlobalDescribe()
    {
        return rawGlobalDescribe;
    }

    public static GlobalDescribeMap getGlobalDescribe()
    {
        return wrappedGlobalDescribe;
    }
    //Useful when working in heap space constrained environments.
    //Existing references to SObjectDescribe instances will continue to work.
    public static void flushCache()
    {
        rawGlobalDescribe = null;
        instanceCache = null;
    }

    /**
     * This class handles emulating a Map<String,Object>'s non-mutating instance methods and helps navigate the complex topic of
     * handling implicit namespace behavior like pre-APIv29 did, while also allowing fully qualified references.
     * Note that this requires the API version of DescribeWrapper to be 29 or higher to function properly.
     *
     * Due to the lack of language support for covariant return types sublasses are responsible for implementing the get methods.
     * A minimal implementation of these would be a cast and returning getObject's result.
    **/
    private abstract class NamespacedAttributeMap
    {
        protected String currentNamespace;
        protected Map<String,Object> values;

        protected NamespacedAttributeMap(Map<String,Object> values)
        {
            //namespace detection courtesey http://salesforce.stackexchange.com/a/28977/60
            currentNamespace = DescribeWrapper.class.getName().substringBefore('DescribeWrapper').removeEnd('.').toLowerCase();
            this.values = values;
        }
        //A no-args constructor to allow subclasses with different contructor signatures
        protected NamespacedAttributeMap()
        {
            this(new Map<String,Object>());
        }
        /**
         * A convenient shortcut for invoking #getObject(name, true)
        **/
        protected virtual Object getObject(String name)
        {
            return this.getObject(name, true);
        }
        /**
         *
        **/
        protected virtual Object getObject(String name, Boolean implyNamespace)
        {
            if (name == null)
            {
                return null;
            }

            String preferredValue = ((implyNamespace ? currentNamespace+'__' : '') + name).toLowerCase();
            if (values.containsKey(preferredValue))
            {
                return values.get(preferredValue);
            }
            else if (implyNamespace)
            {
                return values.get(name.toLowerCase());
            }
            else
            {
                return null;
            }
        }

        public virtual Boolean containsKey(String name)
        {
            return this.containsKey(name, true);
        }

        public virtual Boolean containsKey(String name, Boolean implyNamespace)
        {
            if (name == null)
            {
                return null;
            }

            String preferredValue = ((implyNamespace ? currentNamespace+'__' : '') + name).toLowerCase();

            return (
                values.containsKey(preferredValue) ||
                implyNamespace && values.containsKey(name.toLowerCase())
            );
        }

        public virtual Integer size()
        {
            return values.size();
        }

        /**
         * Returns the key set of the map.
         * Note: unlike other NamespacedAttributeMap methods keySet defaults implyNamespace to false if not specified.
        **/
        public virtual Set<String> keySet()
        {
            return this.keySet(false);
        }

        public virtual Set<String> keySet(Boolean implyNamespace)
        {
            if (implyNamespace)
            {
                Set<String> result = new Set<String>();
                for (String key:values.keySet())
                {
                    result.add(
                        key.removeStartIgnoreCase(currentNamespace+'__')
                    );
                }

                return result;
            }
            else
            {
                return values.keySet();
            }
        }
    }

    /**
     * A subclass of NamespacedAttributeMap for handling the data returned by #DescribeSObjectResult.fields.getMap
    **/
    public class FieldsMap extends NamespacedAttributeMap
    {
        private FieldsMap(Map<String,SObjectField> values)
        {
            super(values);
        }

        public SObjectField get(String name)
        {
            return this.get(name, true);
        }

        public SObjectField get(String name, Boolean implyNamespace)
        {
            return (SObjectField) this.getObject(name, implyNamespace);
        }

        public List<SObjectField> values()
        {
            return (List<SObjectField>) values.values();
        }

    }

    /**
     * A subclass of NamespacedAttributeMap for handling the data returned by #getGlobalDescribe
    **/
    public class GlobalDescribeMap extends NamespacedAttributeMap
    {
        private GlobalDescribeMap(Map<String,SObjectType> values)
        {
            super(values);
        }

        public SObjectType get(String name)
        {
            return this.get(name, true);
        }

        public SObjectType get(String name, Boolean implyNamespace)
        {
            return (SObjectType) this.getObject(name, implyNamespace);
        }

        public List<SObjectType> values()
        {
            return (List<SObjectType>) values.values();
        }
    }


    public abstract class DescribeException extends Exception
    {

    }

    public class DuplicateDescribeException extends DescribeException
    {

    }
    public class InvalidDescribeException extends DescribeException
    {

    }
}