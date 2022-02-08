classdef PsyShell < handle
properties
    key
    cmds
    cmdNames

    str
    pos
    strMode
    strFlag

    bStrCaptrue
    bPrompt
    bUp
    bInit
    lastCmd=cell(10,1)
    lastAct=cell(10,1)

    msg
    msgInit
end
properties(Hidden)
    Key
end
properties(Access=private)
    Viewer
end
methods
    function obj=PsyShell(viewer)
        obj.Viewer=viewer;

        obj.Key=Key('keyDefName','PtchsViewer');
        obj.init_update();
    end
    function obj=resetKey(obj)
        obj.Key.change_def([],obj.Key.KeyDef.defMode);
        obj.init_update();
        obj.Key.KeyStr.clear_str;
    end
    function obj=changeKey(obj,moude,def)
        obj.Key.change_def(moude,def);
        obj.init_update();
        obj.Key.KeyStr.clear_str;
    end
    function obj=init_update(obj)
        obj.bUp=struct();

        obj.bUp.Flags=1;
        obj.bUp.Viewer=1;
        obj.bUp.key=1;
        obj.bUp.cmd=1;
        obj.bUp.str=1;
        obj.bUp.ex=0; % XXX rm?


        obj.bUp.Filter=1;
        obj.bUp.patch=1;
        obj.bUp.im=1;

        obj.bUp.win=1;
        if obj.Viewer.bPsy % XXX rm?
            obj.bUp.tex=1;
        else
            obj.bUp.tex=0;
        end

        obj.bInit=true;
    end
    function obj=reset_update(obj)
        obj.bUp.Flags=0;
        obj.bUp.Viewer=0;
        obj.bUp.key=0;
        obj.bUp.cmd=0;
        obj.bUp.str=0;
        obj.bUp.ex=0;

        obj.bUp.Filter=0;
        obj.bUp.patch=0;
        obj.bUp.im=0;

        obj.bUp.win=0;

        obj.bUp.tex=0;
    end
%% GET
    function out=returnString(obj)
        out=obj.Key.returnString();
    end
    function [str,pos,mode,flag]=getString(obj)
        [str,pos,mode]=obj.Key.getString();
        flag=[];
    end
    function literal=getKeys(obj)
        [literal]=obj.Key.literal;
    end
    function out=getKeyDef(obj)
        out=obj.Key.KeyDef;
    end
    function out=getKeyDefName(obj)
        out=obj.Key.KeyDef.name;
    end
    function moude=getMode(obj)
        moude=obj.Key.KeyDef.mode;
    end
    function moude=getLastMode(obj)
        moude=obj.Key.lastMode;
    end
    function getKeyDefStrings(obj)
        obj.Key.KeyDef.get_key_def_strings();
    end
%% MAIN
    function [exitflag,bUpdate,msg]=main(obj)
        [exitflag,bUpdate]=obj.read();
        msg=obj.msg;
    end
    function [exitflag,bUp,key,cmds,str,pos]=read(obj)
        key=[];
        cmds=[];
        str=[];
        pos=[];
        if ~obj.bInit
            obj.reset_update();
        else
            obj.bInit=false;
        end
        exitflag=obj.Key.read();
        if exitflag
            bUp=obj.bUp;
            return
        end

        [exitflag, literal, obj.cmds, obj.cmdNames,~,msg]=obj.Key.convert();
        if ~isempty(msg)
            obj.msg=msg;
            obj.bUp.cmd=true;
        end
        if iscell(obj.cmdNames)
            obj.cmdNames(cellfun(@isempty,obj.cmdNames))=[];
        end
        if~ isempty(literal)
            obj.key=literal;
            key=obj.key;
            obj.bUp.key=1;
        end
        if exitflag
            bUp=obj.bUp;
            return
        end
        cmds=obj.cmds;
        [obj.str,obj.pos,obj.strMode,obj.strFlag]=obj.Key.getString();
        str=obj.str;
        pos=obj.pos;

        obj.parse_cmds(false);
        if obj.bUp.cmd
            obj.append_action_history(obj.cmdNames);
        end
        obj.bUp.str=true;
        bUp=obj.bUp;
    end
    function append_action_history(obj,lastAct)
        if iscell(lastAct)
            n=numel(lastAct);
            obj.lastAct(1:n-10)=[];
            obj.lastAct{end+1}=lastAct;
        else
            obj.lastAct(1:end-9)=[];
            obj.lastAct{end+1}={lastAct};
        end
    end
    function append_cmd_history(obj,lastCmd)
        obj.lastCmd(1:end-9)=[];
        obj.lastCmd{end+1}=lastCmd;
    end
    function parse_cmds(obj,bExReturn)
        cmds=obj.cmds;
        obj.msgInit=true;
        for i = 1:length(cmds)
            [dest,comp,cmd,det]=obj.splitCmd(cmds{i});
            obj.flag_update(dest,comp);
            if ismember(dest,{'str','key'})
                if bExReturn
                    obj.Key.read_meta({cmd,det{1}});
                else
                    continue
                end
            elseif ismember(dest,{'Cmd','cmd'})
                if ismethod('PsyShell',cmd)
                    obj.(cmd)(det{:});
                else
                    obj.append_msg(['No such command ' cmd ' for Cmd']);
                    exitflag=true;
                    return
                end
            elseif strcmp(dest,'go') %&& bMethod
                try
                    obj.Viewer.(cmd)(det{:});
                catch ME
                    if strcmp(ME.identifier,'MATLAB:noSuchMethodOrField')
                        obj.append_msg(['No such command ' cmd ' for Viewer']);
                        exitflag=true;
                        return
                    else
                        rethrow(ME);
                    end
                end
            elseif isfield(obj.bUp,comp) %&& ~bMethod
                exitflag=obj.run_cmd(dest,cmd,det);
                if exitflag; return; end
            end
        end
    end
    function [dest,comp,CMD,det]=splitCmd(obj,cmd)
        if iscell(cmd{1})
            comp=cmd{1}{1};
            bCell=true;
        else
            comp=cmd{1};
            bCell=false;
        end
        if contains(comp,':')
            spl=strsplit(comp,':');
            comp=spl{1};
            if bCell
                dest=cmd{1};
                dest{1}=strrep(dest{1},comp,'');
            else
                dest=spl{2};
            end
        elseif bCell
            dest{1}=cmd{1};
        else
            dest=comp;
        end


        CMD=cmd{2};
        if length(cmd) >= 3
            det=cmd(3:end);
        else
            det={};
        end
        cind=cellfun(@iscell,det);
        if ~isempty(cind) && any(cind)
            det(~cind)=obj.parse_meta_args(det(~cind));
            det(cind)=cellfun(@obj.parse_meta_args,det(cind),'UniformOutput',false);
        else
            %if strcmp(cmd{1},'Filter')
                %2
            %end
            det=obj.parse_meta_args(det);
        end
    end
    function det=parse_meta_args(obj,det,str)
        inds=find(cellfun(@(x) ischar(x) && strcmp(x,'$0'),det));
        if isempty(inds)
            return
        end
        if nargin < 3
            str=obj.getString();
            str=strsplit(str,[' ']);
            str(cellfun(@isempty,str))=[];
        end
        if isempty(str)
            return
        end
        n=numel(det);
        for i = length(inds):-1:1
            ind=inds(i);
            if ind==1 && ind==n
                det=str;
            elseif ind==1
                det=[str det{ind+1:end}];
            elseif ind==n
                det=[det{1:ind-1} str];
            else
                det=[det{1:ind-1} str det{ind+1:end}];
            end

        end
        ind=cellfun(@(x) ischar(x) && Str.Num.is(x,'all'),det);
        if any(ind)
            det(ind)=cellfun(@str2double,det(ind),'UniformOutput',false);
        end
    end
    function flag_update(obj,dest,comp)
        obj.bUp.cmd=true;
        switch dest
        case 'go'
            obj.bUp.Filter=true;
            obj.bUp.patch=true;
            obj.bUp.Flags=true;
            obj.bUp.im=true;
            obj.bUp.win=true;
        case 'im'
            obj.bUp.patch=true;
            obj.bUp.im=true;
            obj.bUp.win=true;
        case {'str','key'}
            obj.bUp.(dest)=true;
        case {'cmd','Cmd'}
             pass;
        otherwise
            if isfield(obj.bUp, comp)
                obj.bUp.(comp)=true;
            else
                obj.bUp.cmd=false;
            end
        end
    end
    function exitflag=run_cmd(obj,dest,cmd,det)
        exitflag=false;
        if strcmp(dest,'Viewer')
            bView=true;
            bMethod=ismethod(obj.Viewer,cmd);
        else
            bView=false;
            bMethod=ismethod(obj.Viewer.(dest),cmd);
        end


        m=[];
        if bMethod && bView
            try
                m=obj.Viewer.(cmd)(det{:});
            catch ME
                if strcmp(ME.identifier,'MATLAB:maxlhs')
                    obj.Viewer.(cmd)(det{:});
                else
                    rethrow(ME);
                end
            end
        elseif bMethod
            try
                m=obj.Viewer.(dest).(cmd)(det{:});
            catch ME
                if strcmp(ME.identifier,'MATLAB:maxlhs')
                    obj.Viewer.(dest).(cmd)(det{:});
                else
                    rethrow(ME);
                end
            end
        elseif strcmp(cmd,'set')
            obj.set_fun(dest,det{:});
        elseif strcmp(cmd,'toggle')
            obj.toggle_fun(dest,det{:});
        else
            m=(['Invalid command ' cmd ' to ' dest ]);
            exitflag=true;
        end
        obj.append_msg(m);
    end
    function append_msg(obj,msg)
        if ~isempty(msg) && ischar(msg)
            if obj.msgInit
                obj.msgInit=false;
                obj.msg={};
            end
            obj.msg{end+1}=msg;
        end
    end
%% HANDLE EX
    function ex_return(obj,str)
        if nargin < 2
            str=obj.Key.returnString();
        end
        spl=strsplit(str,' ');
        spl(cellfun(@isempty,spl))=[];
        if numel(spl)>1 && numel(spl{1})==1
            excmd=strjoin(spl(1:2),' ');
            %type=spl{1};
            s=3;
        else
            excmd=spl{1};
            %type='';
            s=2;
        end
        if numel(spl) >= s
            args=spl(s:end);
        else
            args={};
        end
        obj.msg='';

        % SHORT TO LONG CMD
        try
            cmd=obj.Key.KeyDef.ex(excmd);
        catch ME
            if strcmp(ME.identifier,'MATLAB:Containers:Map:NoKey')
                obj.msg=['Not a valid command: ' excmd];
                return
            else
                rethrow(ME);
            end
        end
        if ~iscell(cmd{2})
            cmd={cmd};
        end
        if ~isempty(args)
            for i = 1:length(cmd)
                cmd{i}=obj.parse_meta_args(cmd{i},args);
            end
        end
        %c=0;
            %for j = 3:numel(cmd{i})

            %    if numel(args) >= c+1 && ismember(cmd{i}{j},{'#','$'})
            %        c=c+1;
            %        cmd{i}{j}=args{c};
            %    elseif strcmp(cmd{i}{j},'#')
            %        cmd{i}{j}='';
            %    elseif strcmp(cmd{i}{j},'$')
            %        % TODO handle error msg
            %        return
            %    end
            %end
        obj.cmds=cmd;
        obj.parse_cmds(true);
        obj.bUp.str=true;
        obj.append_cmd_history(str);
    end
    function set_fun(obj,dest,prp,det)
        if numel(det)==1
            obj.set_dest_fun(dest,prp,det{1});
        else
            obj.set_dest_fun(dest,prp,det);
        end
    end
    function toggle_fun(obj,dest,prp,vals)
        if strcmp(dest,'Viewer')
            val=obj.Viewer.(prp);
        else
            val=obj.Viewer.(dest).(prp);
        end
        if nargin >= 4 && iscell(vals)
            ind=find(ismember(vals,val));
            if isempty(ind)
                ind=1;
            end
            new=vals{ind};
        elseif isempty(val) || ~val
            new=true;
        else
            new=false;
        end
        obj.set_dest_fun(dest,prp,new);
    end
    function set_dest_fun(obj,dest,prp,val)
        if ischar(val) && startsWith(val,'@')
            val=eval([ 'obj.Viewer.' val(2:end) ';']);
        end
        if iscell(dest)
            if strcmp(dest{1},'Viewer')
                dest{1}=[];
            end
            setfield(obj.Viewer,dest{:},prp,val);
        elseif strcmp(dest,'Viewer')
            obj.Viewer.(prp)=val;
        else
            obj.Viewer.(dest).(prp)=val;
        end
    end

end
end
