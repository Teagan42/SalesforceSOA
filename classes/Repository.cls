public abstract class Repository
{
    public class Result
    {
        private Id entityId;
        private String[] errorMessages;
        private Boolean successful;
        private SObject record;

        public Result(Id entityId, String[] errorMessages, Boolean successful, SObject record)
        {
            this.entityId = entityId;
            this.errorMessages = errorMessages;
            this.successful = successful;
            this.record = record;
        }

        public String[] getErrors()
        {
            return errorMessages;
        }

        public Id getId()
        {
            return entityId;
        }

        public Boolean isSuccess()
        {
            return successful;
        }

        public SObject getRecord()
        {
            return record.clone();
        }
    }

    private RepositoryOptions defaultOption;

    public Repository(RepositoryOptions defaultOption)
    {
        setDefaultOptions(defaultOption);
    }

    public void setDefaultOptions(RepositoryOptions defaultOption)
    {
        this.defaultOption = defaultOption;
    }
}