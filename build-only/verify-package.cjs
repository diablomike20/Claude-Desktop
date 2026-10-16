const fs=require('fs'),path=require('path'),crypto=require('crypto');
const [source,bundle,reportFile]=process.argv.slice(2);
const asar=require(require.resolve('@electron/asar',{paths:[source]}));
const archive=path.join(bundle,'resources','app.asar');
const required=['dist/index.html','dist-electron/main.js','electron/preload.js','public/logo.png','public/logo.ico'];
for(const file of required){const data=asar.extractFile(archive,file);if(!data.length)throw Error('Missing packaged asset '+file)}
const integrity=JSON.parse(fs.readFileSync(reportFile,'utf8'));
const packaged=[],missing=[];
for(const file of integrity.files){
 if(['package.json','package-lock.json','.gitignore','.eslintrc.cjs','README.md'].includes(file.path))continue;
 let body;try{body=asar.extractFile(archive,file.path)}catch{missing.push(file.path);continue}
 const digest=crypto.createHash('sha256').update(body).digest('hex');
 if(digest!==file.sha256)throw Error('Packaged source differs from original '+file.path);
 packaged.push(file.path);
}
const pkg=JSON.parse(asar.extractFile(archive,'package.json').toString('utf8'));
if(pkg.version!=='1.0.0'||pkg.main!=='dist-electron/main.js')throw Error('Wrong packaged application metadata');
integrity.packaged_original_files=packaged;
integrity.original_files_excluded_by_packager=missing;
integrity.packaged_required_assets=required;
integrity.packaged_runtime_metadata={name:pkg.name,version:pkg.version,main:pkg.main};
fs.writeFileSync(reportFile,JSON.stringify(integrity,null,2));
console.log(JSON.stringify({packaged_original_files:packaged.length,required_assets:required.length,archive_checked:true}));
