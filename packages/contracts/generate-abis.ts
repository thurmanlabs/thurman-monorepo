import fs from 'fs';
import path from 'path';

const OUT_DIR = './out';
const EXPORT_DIR = './src/abi';

// Get all contract .json files from Foundry output
function findAbiFiles(dir: string): string[] {
  const files: string[] = [];
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...findAbiFiles(fullPath));
    } else if (entry.name.endsWith('.json') && !entry.name.includes('.dbg.')) {
      files.push(fullPath);
    }
  }
  return files;
}

const abiFiles = findAbiFiles(OUT_DIR);

// Clear and recreate export directory
if (fs.existsSync(EXPORT_DIR)) {
  fs.rmSync(EXPORT_DIR, { recursive: true });
}
fs.mkdirSync(EXPORT_DIR, { recursive: true });

const exports: string[] = [];

for (const filePath of abiFiles) {
  const artifact = JSON.parse(fs.readFileSync(filePath, 'utf-8'));
  
  // Extract contract name from file path
  // e.g., "./out/HelloArchitect.sol/HelloArchitect.json" -> "HelloArchitect"
  const contractName = path.basename(filePath, '.json');
  
  // Skip if no ABI
  if (!artifact.abi || artifact.abi.length === 0) continue;
  
  // Generate TypeScript file with as const
  const tsContent = `// Generated from ${path.relative(process.cwd(), filePath)}
export const ${contractName}Abi = ${JSON.stringify(artifact.abi, null, 2)} as const;
`;
  
  const outputPath = path.join(EXPORT_DIR, `${contractName}.ts`);
  fs.writeFileSync(outputPath, tsContent);
  
  exports.push(`export { ${contractName}Abi } from './${contractName}';`);
  console.log(`✓ Generated ${contractName}.ts`);
}

// Create index file
fs.writeFileSync(path.join(EXPORT_DIR, 'index.ts'), exports.join('\n'));
console.log(`\n✓ Generated index.ts with ${exports.length} contracts`);