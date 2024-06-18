using NUnit.Framework;
using NUnit.Framework.Interfaces;
using NUnit.Framework.Internal;

namespace Tests;

[AttributeUsage(AttributeTargets.Method | AttributeTargets.Class | AttributeTargets.Assembly, AllowMultiple = false, Inherited = false)]
public sealed class TableApiOnlyAttribute : NUnitAttribute, IApplyToTest
{
    public void ApplyToTest(Test test)
    {
        if (test.RunState == RunState.NotRunnable)
        {
            return;
        }

        if (Environment.GetEnvironmentVariable("CosmosConnectionString_Api") == "Table")
        {
            return;
        }

        test.RunState = RunState.Ignored;
        test.Properties.Set(PropertyNames.SkipReason, "Skipping test because CosmosConnectionString_Api is not set to 'Table'");
    }
}

[AttributeUsage(AttributeTargets.Method | AttributeTargets.Class | AttributeTargets.Assembly, AllowMultiple = false, Inherited = false)]
public sealed class CoreSqlOnlyAttribute : NUnitAttribute, IApplyToTest
{
    public void ApplyToTest(Test test)
    {
        if (test.RunState == RunState.NotRunnable)
        {
            return;
        }

        if (Environment.GetEnvironmentVariable("CosmosConnectionString_Api") == "Sql")
        {
            return;
        }

        test.RunState = RunState.Ignored;
        test.Properties.Set(PropertyNames.SkipReason, "Skipping test because CosmosConnectionString_Api is not set to 'Sql'");
    }
}