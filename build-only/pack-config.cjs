const fs=require('fs'),path=require('path');
const [source,output,report]=process.argv.slice(2);
const pkg=JSON.parse(fs.readFileSync(path.join(source,'package.json'),'utf8'));
const config=structuredClone(pkg.build),normalizations=[];
for(const key of ['oneClick','perMachine','allowToChangeInstallationDirectory']){
 const value=config.nsis[key];
 if(value==='true'||value==='false'){
  config.nsis[key]=value==='true';
  normalizations.push({field:'nsis.'+key,source_value:value,packaging_value:config.nsis[key]});
 }
}
fs.writeFileSync(output,JSON.stringify(config,null,2));
fs.writeFileSync(report,JSON.stringify({application_source_changed:false,package_json_changed:false,lockfile_changed:false,normalizations,publish:'never'},null,2));
