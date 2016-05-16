public virtual UnitOfWork
    implements IUnitOfWork
{
    public class UnitOfWorkException extends Exception {}

    private class Relationship
    {
        public SObject record;
        public SObjectField relatedToField;
        public SObject relatedTo;

        /**
         * Instantiate a new relationship instance
         *
         * @param record Record that is to be related
         * @param relatedToField The field on the record that is the foreign key
         * @param relatedTo The record that is to be related to
         **/
        public Relationship(SObject record, SObjectField relatedToField, SObject relatedTo)
        {
            this.record = record;
            this.relatedToField = relatedToField;
            this.relatedTo = relatedTo;
        }
    }

    private class Relationships
    {
        private List<Relationship> relationships = new List<Relationship>();

        /**
         * Relsove all relationships in the list
         **/
        public void resolve()
        {
            for (Relationship relationship : relationships)
            {
                relationship.record.put(relationship.relatedToField, relationship.relatedTo.Id);
            }
        }

        /**
         * Add a relationship to the list
         *
         * @param record The record to be related
         * @param relatedToField The field on the record that is the foreign key
         * @param relatedTo The record to relate to
         **/
        public void add(SObject record, SObjectField relatedToField, SObject relatedTo)
        {
            Relationship relationship = new Relationship(record, relatedToField, relatedTo);
            relationships.add(relationship);
        }
    }

    private IRepository repository;
    private List<SObjectType> objectTypes = new List<SObjectType>();
    private Map<SObjectType, List<SObject>> typeToNewRecords = new Map<SObjectType, List<SObject>>();
    private Map<SObjectType, List<SObject>> typeToDirtyRecords = new Map<SObjectType, List<SObject>>();
    private Map<SObjectType, List<SObject>> typeToDeletedRecords = new Map<SObjectType, List<SObject>>();
    private Map<SObjectType, Relationships> typeToRelationships = new Map<SObjectType, Relationships>();
    private List<IWorkExecutor> workExecutors = new List<IWorkExecutor>();

    /**
     * Default implementation of the on register type event
     **/
    public virtual void onRegisterType(SObjectType sObjectType) {}

    /**
     * Default implementation of the on work starting event
     **/
    public virtual void onCommitWorkStarting() {}

    /**
     * Default implementation of the database operations starting event
     **/
    public virtual void onDBStarting() {}

    /**
     * Default implementation of the database operations finished event
     **/
    public virtual void onDBFinished() {}

    /**
     * Default implementations of the work executor phase starting event
     **/
    public virtual void onDoWorkStarting() {}

    /**
     * Default implementation of the work executor phase finished event
     **/
    public virtual void onDoWorkFinished() {}

    /**
     * Default implemenation of the commit work finishing phase event
     **/
    public virtual void onCommitWorkFinishing() {}

    /**
     * Default implementation of the commit work finished event
     **/
    public virtual void onCommitWorkFinished(Boolean wasSuccessful) {}

    /**
     * Instantiate a new unit of work for the specified object types
     *
     * @param objectTypes List of object types for this unit of work
     * @param repository Repository for database operations
     **/
    public UnitOfWork(List<SObjectType> objectTypes, IRepository repository)
    {
        this.repository = repository;
        this.objectTypes = objectTypes.clone();

        for (SObjectType sObjectType : this.objectTypes)
        {
            // register the type
            handleRegisterType(sObjectType);
        }
    }

    /**
     * Registers a new record to be committed to the repository
     *
     * @param record The record to be committed
     **/
    public void registerNew(SObject record)
    {
        registerNew(record, null, null);
    }

    /**
     * Registers new records to be committed to the repository
     *
     * @param records The records to be committed
     **/
    public void registerNew(List<SObject> records)
    {
        for (SObject record : records)
        {
            registerNew(record, null, null);
        }
    }

    /**
     * Registers a new record to be committed to the repository
     *
     * @param record The record to be committed
     * @param parentRelationshipField The field on the record that is the foreign key to the parent record
     * @param parentRecord The parent record
     **/
    public void registerNew(SObject record, SObjectField parentRelationshipField, SObject parentRecord)
    {
        if (!String.isBlank(record.Id))
        {
            throw new UnitOfWorkException('Only new records can be registered as new.');
        }

        SObjectType sObjectType = record.getSObjectType()
        if (!typeToNewRecords.containsKey(sObjectType))
        {
            throw new UnitOfWorkException(String.format(
                'SObject type {0} is not supported by this unit of work',
                new String[] { sObjectType }));
        }

        typeToNewRecords.get(sObjectType).add(record);

        if (parentRecord != null && parentRelationshipField != null)
        {
            registerRelationship(record, parentRelationshipField, parentRecord);
        }
    }

    /**
     * Register a relationship between two records that have yet to be inserted to the database. This information will be
     *  used during the commitWork phase to make the references only when related records have been inserted to the database.
     *
     * @param record An existing or newly created record
     * @param relatedToField A SObjectField referene to the lookup field that relates the two records together
     * @param relatedTo A SObject instance (yet to be commited to the database)
     */
    public void registerRelationship(SObject record, SObjectField relatedToField, SObject relatedTo)
    {
        SObjectType sObjectType = record.getSObjectType();

        if (!typeToNewRecords.containsKey(sObjectType))
        {
            throw new UnitOfWorkException(String.format(
                'SObject type {0} is not supported by this unit of work',
                new String[] { sObjectType }));
        }

        relationships.get(sObjectType).add(record, relatedToField, relatedTo);
    }

    /**
     * Register a generic peace of work to be invoked during the commitWork phase
     *
     * @param work The executor to register
     **/
    public void registerWork(IWorkExecutor work)
    {
        workExecutors.add(work);
    }

    /**
     * Register an existing record to be updated during the commitWork phase
     *
     * @param record An existing record
     **/
    public void registerDirty(SObject record)
    {
        if (String.isBlank(record.Id)
        {
            throw new UnitOfWorkException('New records cannot be registered as dirty');
        }

        SObjectType sObjectType = record.getSObjectType();

        if (!typeToDirtyRecords.containsKey(sObjectType))
        {
            throw new UnitOfWorkException(String.format(
                'SObject type {0} is not supported by this unit of work',
                new String[] { sObjectType }));
        }
        typeToDirtyRecords.get(sObjectType).put(record.Id, record);
    }

    /**
     * Register a list of existing records to be updated during the commitWork phase
     *
     * @param records A list of existing records
     **/
    public void registerDirty(List<SObject> records)
    {
        for(SObject record : records)
        {
            registerDirty(record);
        }
    }

    /**
     * Register an existing record to be deleted during the commitWork method
     *
     * @param record An existing record
     **/
    public void registerDeleted(SObject record)
    {
        if (String.isBlank(record.Id))
        {
            throw new UnitOfWorkException('New records cannot be registered for deletion');
        }

        SObjectType sObjectType = record.getSObjectType();

        if (!typeToDeletedRecords.containsKey(sObjectType))
        {
            throw new UnitOfWorkException(String.format(
                'SObject type {0} is not supported by this unit of work',
                new String[] { sObjectType }));
        }

        typeToDeletedRecords.get(sObjectType).put(record.Id, record);
    }

    /**
     * Register a list of existing records to be deleted during the commitWork method
     *
     * @param records A list of existing records
     **/
    public void registerDeleted(List<SObject> records)
    {
        for(SObject record : records)
        {
            registerDeleted(record);
        }
    }

    /**
     * Commits work to the repository.
     **/
    public void commitWork()
    {
        // Fire event
        onCommitWorkStarting();

        IRepository.SavePoint sp = repository.getSavePoint();
        Boolean wasSuccessful = false;

        try
        {
            onDBStarting();

            // Insert all new records by type
            for(SObjectType sObjectType : objectTypes)
            {
                relationships.get(sObjectType).resolve();
                repository.doInsert(typeToNewRecords.get(sObjectType));
            }

            // Update all dirty records by type
            for(SObjectType sObjectType : objectTypes)
            {
                repository.doUpdate(typeToDirtyRecords.get(sObjectType).values());
            }

            // Delete by type (in reverse dependency order)
            Integer objectIdx = m_sObjectTypes.size() - 1;
            while (objectIdx >= 0)
            {
                repository.doDelete(typeToDeletedRecords.get(objectTypes[objectIdx--]).values());
            }


            onDBFinished();

            onDoWorkStarting();

            // Execute work executors
            for(IWorkExecutor work : m_workList)
            {
                work.execute();
            }

            onDoWorkFinished();

            onCommitWorkFinishing();

            wasSuccessful = true;
        }
        catch (Exception e)
        {
            repository.rollback(sp);

            throw e;
        }
        finally
        {
            onCommitWorkFinished(wasSuccessful);
        }
    }

    /**
     * Registers the type of SObject to be used for database operations
     *
     * @param sObjectType The type to register
     **/
    private void handleRegisterType(SObjectType sObjectType)
    {
        typeToNewRecords.put(sObjectType, new List<SObject>());
        typeToDirtyRecords.put(sObjectType, new Map<Id, SObject>());
        typeToDeletedRecords.put(sObjectType, new Map<Id, SObject>());
        relationships.put(sObjectType, new Relationships());

        // give derived class opportunity to register the type
        onRegisterType(sObjectType);
    }
}