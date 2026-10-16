const fs=require('fs'),path=require('path');
const { _electron:electron }=require('playwright');
const [executable,output,qa]=process.argv.slice(2);
(async()=>{
 const report={ok:false,claude_login_tested:false,chat_message_sent:false,auto_update_tested:false};
 let application;
 try{
  application=await electron.launch({executablePath:path.resolve(executable),cwd:path.dirname(path.resolve(executable)),timeout:60000,args:['--disable-gpu']});
  const main=await application.firstWindow({timeout:30000});
  report.application=await application.evaluate(({app,BrowserWindow})=>({name:app.getName(),version:app.getVersion(),isPackaged:app.isPackaged,appPath:app.getAppPath(),nativeWindows:BrowserWindow.getAllWindows().map(w=>({title:w.getTitle(),visible:w.isVisible()}))}));
  if(!report.application.isPackaged||report.application.version!=='1.0.0')throw Error('Unexpected application version or unpackaged runtime');
  report.main_window_opened=true;
  // Only the automatic updater dialog is dismissed in this test; no source bytes change.
  await application.evaluate(({dialog})=>{dialog.showMessageBox=async()=>({response:0,checkboxChecked:false})});
  const pending=application.waitForEvent('window',{timeout:30000});
  await application.evaluate(({Menu})=>{
   const preferences=Menu.getApplicationMenu().items.find(i=>i.label==='Preferences');
   preferences.submenu.items.find(i=>i.label==='Control Center').click();
  });
  const control=await pending;
  await control.waitForLoadState('domcontentloaded');
  await control.getByText('Settings',{exact:true}).click({timeout:20000});
  await control.getByText('Config Path:',{exact:false}).waitFor({timeout:20000});
  const bridge=await control.evaluate(async()=>({exists:!!window.electronAPI,config:await window.electronAPI.getConfig(),configPath:await window.electronAPI.getConfigPath()}));
  if(!bridge.exists||!bridge.config||typeof bridge.config._main_width!=='number')throw Error('Packaged preload/IPC bridge not working');
  report.control_center_loaded=true;report.settings_loaded=true;report.preload_ipc_config_read=true;
  await control.getByRole('tab',{name:'Main Window',exact:true}).click();
  await control.getByText('Default Width:',{exact:true}).waitFor();
  await control.getByRole('tab',{name:'General',exact:true}).click();
  if(qa){fs.mkdirSync(qa,{recursive:true});await control.screenshot({path:path.join(qa,'control-center.png')})}
  report.remote_page={url:main.url(),title:await main.title().catch(()=>''),authenticated_session_tested:false};
  report.renderer_errors=await control.evaluate(()=>({body_present:document.body.innerText.includes('Settings')}));
  if(!report.renderer_errors.body_present)throw Error('Empty control-center renderer');
  const process=application.process();
  await application.close();application=null;
  report.clean_shutdown=process.exitCode===0;
  if(!report.clean_shutdown)throw Error('Application did not exit cleanly: '+process.exitCode);
  report.ok=true;
 }catch(error){report.error=error.stack||String(error);throw error}
 finally{
  if(application)await application.close().catch(()=>{});
  fs.writeFileSync(output,JSON.stringify(report,null,2));
  console.log(JSON.stringify(report));
 }
})().catch(e=>{console.error(e);process.exit(1)});
