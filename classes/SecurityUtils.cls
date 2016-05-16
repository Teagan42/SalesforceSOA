public class fflib_SecurityUtils
{
    private Enum OperationType
    {
        CREATE,
        READ,
        MODIFY,
        DEL
    }

    private static final String ERROR_OBJECT_NOT_INSERTABLE = '';
    private static final String ERROR_OBJECT_NOT_READABLE = '';
    private static final String ERROR_OBJECT_NOT_UPDATEABLE = '';
    private static final String ERROR_OBJECT_NOT_DELETABLE = '';
    private static final String ERROR_FIELD_NOT_INSERTABLE = '';
    private static final String ERROR_FIELD_NOT_READABLE = '';
    private static final String ERROR_FIELD_NOT_UPDATEABLE = '';

    public virtual class SecurityException extends Exception
    {
        protected OperationType operation;
        protected Schema.SObjectType objectType;
    }

    /**
     * Represents a user's lack of read/create/update/delete access at a profile or
     *  permission set level. NOT SHARING
     **/
    public class CrudException extends SecurityException
    {
        private CrudException(OperationType operation, Schema.SObjectType objectType)
        {
            this.operation = operation;
            this.objectType = objectType;

            if(operation == OperationType.CREATE)
            {
                this.setMessage(ERROR_OBJECT_NOT_INSERTABLE);
            }
            else if(operation == OperationType.READ)
            {
                this.setMessage(ERROR_OBJECT_NOT_READABLE);
            }
            else if(operation == OperationType.MODIFY)
            {
                this.setMessage(ERROR_OBJECT_NOT_UPDATEABLE);
            }
            else if(operation == OperationType.DEL)
            {
                this.setMessage(ERROR_OBJECT_NOT_DELETABLE);
            }

            this.setMessage(
                String.format(
                    this.getMessage(),
                    new List<String>{
                        objectType.getDescribe().getName()
                    }
                )
            );
        }
    }
    /**
     * Represents a user's lack of field level security to a specific field at a profile
     *  or permission set level. NOT SHARING
     **/
    public class FlsException extends SecurityException
    {
        private Schema.SObjectField m_fieldToken;

        private FlsException(OperationType operation, Schema.SObjectType objectType, Schema.SObjectField fieldToken)
        {
            this.operation = operation;
            this.objectType = objectType;
            this.m_fieldToken = fieldToken;
            if(operation == OperationType.CREATE)
            {
                this.setMessage(ERROR_FIELD_NOT_INSERTABLE);
            }
            else if(operation == OperationType.READ)
            {
                this.setMessage(ERROR_FIELD_NOT_READABLE);
            }
            else if(operation == OperationType.MODIFY)
            {
                this.setMessage(ERROR_FIELD_NOT_UPDATEABLE);
            }

            this.setMessage(
                String.format(
                    this.getMessage(),
                    new List<String>{
                        objectType.getDescribe().getName(),
                        fieldToken.getDescribe().getName()
                    }
                )
            );
        }
    }

    /**
     * Flag to bypass security validation
     **/
    public static boolean BYPASS_INTERNAL_FLS_AND_CRUD = false;

    /**
     * Checks both insert FLS and CRUD for the specified object type and fields.
     *
     * @exception FlsException if the running user does not have insert rights to any fields in {@code fieldNames}.
     * @exception CrudException if the running user does not have insert rights to {@code objType}
     **/
    public static void checkInsert(SObjectType objType, List<String> fieldNames)
    {
        checkObjectIsInsertable(objType);
        for (String fieldName : fieldNames)
        {
            checkFieldIsInsertable(objType, fieldName);
        }
    }

    /**
     * Identical to {@link #checkInsert(SObjectType,List<String>)}, except with SObjectField instead of String field references.
     *
     * @exception FlsException if the running user does not have insert rights to any fields in {@code fieldTokens}.
     * @exception CrudException if the running user does not have insert rights to {@code objType}
     **/
    public static void checkInsert(SObjectType objType, List<SObjectField> fieldTokens)
    {
        checkObjectIsInsertable(objType);
        for (SObjectField fieldToken : fieldTokens)
        {
            checkFieldIsInsertable(objType, fieldToken);
        }
    }

    /**
     * Checks both read FLS and CRUD for the specified object type and fields.
     *
     * @exception FlsException if the running user does not have read rights to any fields in {@code fieldNames}.
     * @exception CrudException if the running user does not have read rights to {@code objType}
     **/
    public static void checkRead(SObjectType objType, List<String> fieldNames)
    {
        checkObjectIsReadable(objType);
        for (String fieldName : fieldNames)
        {
            checkFieldIsReadable(objType, fieldName);
        }
    }

    /**
     * Identical to {@link #checkRead(SObjectType,List<String>)}, except with SObjectField instead of String field references.
     *
     * @exception FlsException if the running user does not have read rights to any fields in {@code fieldTokens}.
     * @exception CrudException if the running user does not have read rights to {@code objType}
     **/
    public static void checkRead(SObjectType objType, List<SObjectField> fieldTokens)
    {
        checkObjectIsReadable(objType);
        for (SObjectField fieldToken : fieldTokens)
        {
            checkFieldIsReadable(objType, fieldToken);
        }
    }

    /**
     * Checks both update FLS and CRUD for the specified object type and fields.
     *
     * @exception FlsException if the running user does not have update rights to any fields in {@code fieldNames}.
     * @exception CrudException if the running user does not have update rights to {@code objType}
     **/
    public static void checkUpdate(SObjectType objType, List<String> fieldNames)
    {
        checkObjectIsUpdateable(objType);
        for (String fieldName : fieldNames)
        {
            checkFieldIsUpdateable(objType, fieldName);
        }
    }

    /**
     * Identical to {@link #checkUpdate(SObjectType,List<String>)}, except with SObjectField instead of String field references.
     *
     * @exception FlsException if the running user does not have update rights to any fields in {@code fieldTokens}.
     * @exception CrudException if the running user does not have update rights to {@code objType}
     **/
    public static void checkUpdate(SObjectType objType, List<SObjectField> fieldTokens)
    {
        checkObjectIsUpdateable(objType);
        for (SObjectField fieldToken : fieldTokens)
        {
            checkFieldIsUpdateable(objType, fieldToken);
        }
    }

    /**
     * Checks insert field level security only (no CRUD) for the specified fields on {@code objType}
     *
     * @exception FlsException if the running user does not have insert rights to the {@code fieldName} field.
     **/
    public static void checkFieldIsInsertable(SObjectType objType, String fieldName)
    {
        checkFieldIsInsertable(objType, fflib_SObjectDescribe.getDescribe(objType).getField(fieldName));
    }

    /**
     * Identical to {@link #checkFieldIsInsertable(SObjectType,String)}, except with SObjectField instead of String field reference.
     *
     * @exception FlsException if the running user does not have insert rights to the {@code fieldName} field.
     **/
    public static void checkFieldIsInsertable(SObjectType objType, SObjectField fieldToken)
    {
        checkFieldIsInsertable(objType, fieldToken.getDescribe());
    }

    /**
     * Identical to {@link #checkFieldIsInsertable(SObjectType,String)}, except with DescribeFieldResult instead of String field reference.
     *
     * @exception FlsException if the running user does not have insert rights to the {@code fieldName} field.
     **/
    public static void checkFieldIsInsertable(SObjectType objType, DescribeFieldResult fieldDescribe)
    {
        if (BYPASS_INTERNAL_FLS_AND_CRUD)
        {
            return;
        }

        if (!fieldDescribe.isCreateable())
        {
            throw new FlsException(OperationType.CREATE, objType, fieldDescribe.getSObjectField());
        }
    }

    /**
     * Checks read field level security only (no CRUD) for the specified fields on {@code objType}
     *
     * @exception FlsException if the running user does not have read rights to the {@code fieldName} field.
     **/
    public static void checkFieldIsReadable(SObjectType objType, String fieldName)
    {
        checkFieldIsReadable(objType, fflib_SObjectDescribe.getDescribe(objType).getField(fieldName));
    }

    /**
     * Identical to {@link #checkFieldIsReadable(SObjectType,String)}, except with SObjectField instead of String field reference.
     *
     * @exception FlsException if the running user does not have read rights to the {@code fieldName} field.
     **/
    public static void checkFieldIsReadable(SObjectType objType, SObjectField fieldToken)
    {
        checkFieldIsReadable(objType, fieldToken.getDescribe());
    }

    /**
     * Identical to {@link #checkFieldIsReadable(SObjectType,String)}, except with DescribeFieldResult instead of String field reference.
     *
     * @exception FlsException if the running user does not have read rights to the {@code fieldName} field.
     **/
    public static void checkFieldIsReadable(SObjectType objType, DescribeFieldResult fieldDescribe)
    {
        if (BYPASS_INTERNAL_FLS_AND_CRUD)
        {
            return;
        }

        if (!fieldDescribe.isAccessible())
        {
            throw new FlsException(OperationType.READ, objType, fieldDescribe.getSObjectField());
        }
    }


    /**
     * Checks update field level security only (no CRUD) for the specified fields on {@code objType}
     *
     * @exception FlsException if the running user does not have update rights to the {@code fieldName} field.
     **/
    public static void checkFieldIsUpdateable(SObjectType objType, String fieldName)
    {
        checkFieldIsUpdateable(objType, fflib_SObjectDescribe.getDescribe(objType).getField(fieldName));
    }

    /**
     * Identical to {@link #checkFieldIsUpdateable(SObjectType,String)}, except with SObjectField instead of String field reference.
     *
     * @exception FlsException if the running user does not have update rights to the {@code fieldName} field.
     **/
    public static void checkFieldIsUpdateable(SObjectType objType, SObjectField fieldToken)
    {
        checkFieldIsUpdateable(objType, fieldToken.getDescribe());
    }

    /**
     * Identical to {@link #checkFieldIsUpdateable(SObjectType,String)}, except with DescribeFieldResult instead of String field reference.
     *
     * @exception FlsException if the running user does not have update rights to the {@code fieldName} field.
     **/
    public static void checkFieldIsUpdateable(SObjectType objType, DescribeFieldResult fieldDescribe)
    {
        if (BYPASS_INTERNAL_FLS_AND_CRUD)
        {
            return;
        }

        if (!fieldDescribe.isUpdateable())
        {
            throw new FlsException(OperationType.MODIFY, objType, fieldDescribe.getSObjectField());
        }
    }

    /**
     * Checks insert CRUD for the specified object type.
     *
     * @exception CrudException if the running uder does not have insert rights to the {@code objType} SObject.
     **/
    public static void checkObjectIsInsertable(SObjectType objType)
    {
        if (BYPASS_INTERNAL_FLS_AND_CRUD)
        {
            return;
        }

        if (!objType.getDescribe().isCreateable())
        {
            throw new CrudException(OperationType.CREATE, objType);
        }
    }

    /**
     * Checks read CRUD for the specified object type.
     *
     * @exception CrudException if the running uder does not have read rights to the {@code objType} SObject.
     **/
    public static void checkObjectIsReadable(SObjectType objType)
    {
        if (BYPASS_INTERNAL_FLS_AND_CRUD)
        {
            return;
        }

        if (!objType.getDescribe().isAccessible())
        {
            throw new CrudException(OperationType.READ, objType);
        }
    }

    /**
     * Checks update CRUD for the specified object type.
     *
     * @exception CrudException if the running uder does not have update rights to the {@code objType} SObject.
     **/
    public static void checkObjectIsUpdateable(SObjectType objType)
    {
        if (BYPASS_INTERNAL_FLS_AND_CRUD)
        {
            return;
        }

        if (!objType.getDescribe().isUpdateable())
        {
            throw new CrudException(OperationType.MODIFY, objType);
        }
    }

    /**
     * Checks delete CRUD for the specified object type.
     *
     * @exception CrudException if the running uder does not have delete rights to the {@code objType} SObject.
     **/
    public static void checkObjectIsDeletable(SObjectType objType)
    {
        if (BYPASS_INTERNAL_FLS_AND_CRUD)
        {
            return;
        }

        if (!objType.getDescribe().isDeletable())
        {
            throw new CrudException(OperationType.DEL, objType);
        }
    }
}