using Microsoft.Extensions.Configuration;
using Newtonsoft.Json;

namespace Blocks.Genesis
{
    public sealed class BlocksSecret : IBlocksSecret
    {
        public string CacheConnectionString { get; set; }
        public string LogFilesRootDirectory { get; set; }
        public string StorageBasePath { get; set; }
        public string BlocksAuditLogQueueName { get; set; }
        public string TokenIssuer { get; set; }
        public string MessageConnectionString { get; set; }
        public string LogConnectionString { get; set; }
        public string MetricConnectionString { get; set; }
        public string TraceConnectionString { get; set; }

        public static async Task<IBlocksSecret> ProcessBlocksSecret(CloudType cloudType, Dictionary<string, string> cloudConfig)
        {
            ICloudVault cloudVault = CloudVault.GetCloudVault(cloudType);
            var blocksSecret = await cloudVault.ProcessSecrets(new BlocksSecret(), cloudConfig);

            return blocksSecret;
        }

        public static IBlocksSecret ProcessBlocksSecretFromJsonFile(string jsonFilePath)
        {
            var secretConfigJson = File.ReadAllText(jsonFilePath);
            var secretConfig = JsonConvert.DeserializeObject<BlocksSecret>(secretConfigJson);

            return secretConfig;
        }

        public void UpdateProperty(string propertyName, object propertyValue)
        {
            var property = this.GetType().GetProperty(propertyName);

            if (property != null && property.CanWrite)
            {
                property.SetValue(this, propertyValue);
            }
            else
            {
                Console.WriteLine($"Property '{propertyName}' not found or is read-only.");
            }
        }
    }

}
