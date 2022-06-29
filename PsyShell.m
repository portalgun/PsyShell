classdef PsyShell < handle
properties
    key
    cmds
    cmdNames

    str
    pos
    strMode
    strFlag
    strDest=struct()

    bStrCaptrue
    bPrompt
    bUp
    bInit

    nCmds
    Hist
    %Cmd
    %Act
    %Out
    %Msg
    %Typ
    %bView

    msg
    msgInit
    scanexitflag
    nHistory=1000;
end
properties(Hidden)
    fname
    Key
end
properties(Access=private)
    Parent

    bRestore
end
methods
    function obj=PsyShell(parent,defName)
        obj.Parent=parent;

        obj.Key=Key('keyDefName',defName);
        obj.init_update();

        obj.fname=[Env.var('TMP') 'MatPsyShell'];

        obj.init_hist();
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
    function obj=changeMode(obj,moude)
        obj.Key.change_def([],moude);
    end
    function moude=lastMode(obj)
        moude=obj.Key.change_to_lastMode();
    end
%% GET
    function out=returnString(obj,name)
        if nargin < 2
            name=[];
        end
        out=obj.Key.returnString(name);
    end
    function [str,pos,mode,flag,bDiff]=getString(obj,name)
        if nargin < 2
            name=[];
        end
        [str,pos,mode,~,bDiff]=obj.Key.getString(name);
        flag=[];
    end
    function time=popKeyTime(obj)
        time=obj.Key.lastKeyTime(1);
        obj.Key.lastKeyTime(1)=[];
    end
    function literal=getKeys(obj)
        [literal]=obj.Key.literal;
        if ~isempty(literal) && iscell(literal) && iscell(literal{1})
            literal=vertcat(literal{:});
        end
    end
    function out=getKeyDef(obj)
        out=obj.Key.KeyDef;
    end
    function out=getKeyDefName(obj)
        out=regexprep(class(obj.Key.KeyDef),'^KeyDef_','');
    end
    function moude=getMode(obj)
        moude=obj.Key.KeyDef.mode;
    end
    function moude=getLastMode(obj)
        moude=obj.Key.lastMode;
    end
    function txt=getKeyDefString(obj)
        txt=obj.Key.KeyDef.get_mode_key_table();
    end
    function getCmdDefStrings(obj)
        obj.Key.KeyDef.get_cmd_def_strings();
    end
    function appendKeyStr(obj,name,KS,bChange,dests)
        if nargin < 4
            bChange=[];
        end
        obj.Key.append_keyStr(name,KS,bChange);
        if nargin >= 5
            obj.strDest.(name)=dests;
        end
    end
    function changeKeyStr(obj,name)
        obj.Key.changeKeyStr(name);
    end
%% PROMPTS
    function OUT=getHist(obj,typ,n,botPos)
        % typ = cmd OR key
        if nargin < 2 || isempty(typ)
            typ='cmd';
        end
        if nargin < 3 || isempty(n)
            n=8;
        end
        if nargin < 4 || isempty(botPos)
            botPos=0;
        end
        cmd=obj.getCmdHist(n,typ);
        if isempty(cmd)
            OUT='';
            return
        end
        out=obj.getOutHist(n,typ);
        OUT=[cmd; out];
        eInd=logical(cellfun(@isempty,OUT));
        eInd=eInd(:);
        OUT=OUT(:);
        rmInd=logical(cumprod(cellfun(@isempty,OUT))) | eInd;
        N=length(OUT);
        ind=N-n+1:N;
        ind=ind(ind > 0);
        rmInd=rmInd(ind);
        OUT=OUT(ind);
        OUT(rmInd)=[];
        OUT=strjoin(OUT,newline);
        if n-N > 0
            OUT=[repmat(newline,1,n-N) OUT];
        end

    end
    function strs=getOutHist(obj,n,typ)
        % XXX MAKE PRIVATE
        N=sum(obj.Hist.(typ).bView);
        if nargin < 2 || isempty(n) || n > N
            n=N;
        end
        if n==0
            strs=[];
            return
        end
        Out=obj.Hist.(typ).Out(obj.Hist.(typ).bView);
        inds=N-n+1:N;
        strs=arrayfun(@(x) getHist_fun(obj,Out,x),inds,'UniformOutput',false);
        function str=getHist_fun(obj,Out,ind)
            out=Out{ind};
            if (~iscell(out) && isempty(out)) || (iscell(out) && all(cellfun(@isempty,out)))
                str='';
            elseif ischar(out)
                str=out;
            elseif iscell(out)
                str=strjoin(out,newline);
            end
        end
    end
    function strs=getCmdHist(obj,n,typ)
        % XXX MAKE PRIVATE
        N=sum(obj.Hist.(typ).bView);
        if nargin < 2 || isempty(n) || n > N
            n=N;
        end
        if n==0
            strs=[];
            return
        end
        His=obj.Hist.(typ).Cmd(obj.Hist.(typ).bView);
        Typ=obj.Hist.(typ).Typ(obj.Hist.(typ).bView);
        inds=N-n+1:N;
        strs=arrayfun(@(x) getHist_fun(obj,His,Typ,x),inds,'UniformOutput',false);
        function str=getHist_fun(obj,His,Typ,ind)
            cmd=His{ind};
            if isempty(cmd) && isa(cmd,'double')
                str='';
                return
            end
            switch Typ{ind}
                case 'e'
                    pr='-> ';
                case 'p'
                    pr='@  ';
                case 'm'
                    pr='>> ';
                case 'u'
                    pr='$  ';
            end
            if (~iscell(cmd) && isempty(cmd)) || (iscell(cmd) && all(cellfun(@isempty,cmd)))
                str=pr;
            elseif ischar(cmd)
                str=[pr cmd];
            else
                str=[pr strjoin(cmd,[newline pr])];
            end
        end
    end
    function [cmd,pos]=getPrompt(obj,bCursor,bUnicode)
        if nargin < 3
            bUnicode=false;
        end

        if bCursor && bUnicode
            C=sprintf('\x20e8');
        elseif bCursor
            C='|';
        else
            C='';
        end

        [str, pos, mode]=obj.getString('SHELL');
        if bUnicode
            str=[str ' '];
            b=str(1:pos);
            b2=str(2:pos);
            e=str(pos+1:end);
        else
            b=str(1:pos-1);
            b2=b(2:pos-1);
            %b2=b(2:end);
            e=str(pos:end);
        end

        if length(b) > 0
            c=b(1);
        else
            c='';
        end

        moude=obj.getMode();
        if ismember_cell(moude,{'cmd'})
            switch c
                case '.'
                    cmd=['@ ' b2 C e];
                case '>'
                    cmd=['>> ' b2 C e];
                case 'unix'
                    cmd=['$ ' b2 C e];
                otherwise
                    cmd=['-> ' b C e];
            end
        else
            cmd=sprintf([moude '<']);
        end
    end
    function [out,exitflag]=getKeyEcho(obj,bAct)
        exitflag=0;
        % TODO NUM
        if nargin < 2
            bAct=false;
        end
        mode=obj.getMode;
        literal=obj.getKeys;
        if iscell(literal)
            if all(cellfun(@isempty,literal))
                out='';
                exitflag=1;
                return % NECESSARY
            else
                literal=strjoin(literal,' ');
            end
        end
        out=[ mode ': ' literal ];
        if bAct
            lst=obj.Hist.key.Cmd{end};
            if isempty(lst) || (iscell(lst) && all(cellfun(@isempty,lst)))
                exitflag=1;
                return
            end
            if iscell(lst) && ~isempty(lst)
                lst=strjoin(lst,' :: ');
            end
            out=[out ' :: ' lst];
        end
        if ~obj.Key.bListen
            out=['X ' out];
        end
        out=strrep(out,'\','/');
    end
%% MAIN
    function test(obj)
        waitforbuttonpress
        obj.scan;
        waitforbuttonpress
        obj.scan;
        obj.convert();
    end
    function testLoop(obj)
        bslen=0;
        cl=onCleanup(@() ListenChar(0));
        ListenChar(2);
        msg='';
        while true
            exitflag=obj.Key.read();
            if ~exitflag
                m=evalc('obj.convert();');
                if ~isempty(m)
                    msg=m;
                end

                % CMD
                [cmd,pos]=obj.getPrompt(true,true);

                %ECHO
                [t,exitflag]=obj.getKeyEcho(true);
                if ~exitflag
                    txt=t;
                end
                str=[newline cmd newline txt newline msg];
                fprintf([repmat('\b',1,bslen) str]);
                bslen=length(str);
            end
        end
        %txt=obj.Key.KeyDef.get_mode_key_table();
    end
    function [bCmd,bUp,msg,bKeyChange]=main(obj)
        exitflag=obj.scan();
        if exitflag
            msg=obj.msg;
            bUp=obj.bUp;
            bCmd=false;
            bKeyChange=false;
            return
        else
            [exitflag,bKeyChange]=obj.convert();
            msg=obj.msg;
            bUp=obj.bUp;
            bCmd=true;
        end
    end
    function [exitflag,bUp,key,cmds,str,pos]=read(obj)
        if ~obj.bInit
            obj.bUp=cell(0,1);
        else
            obj.init_update(); % YES?
        end
        obj.bInit=false;

        exitflag=obj.scan();
        if exitflag
            bUp=obj.bUp; key=[]; cmds=[]; str=[]; pos=[];
            return
        end

        [exitflag,bUp,key,cmds,str,pos]=obj.convert();
    end
    function exitflag=scan(obj)
        [exitflag]=obj.Key.read();
    end
    function scanUntil(obj)
        exitflag=0;
        while ~exitflag
            exitflag=obj.Key.read();
        end
    end
    function [exitflag,bKeyChange]=convert(obj)
        % KEY
        [exitflag,  obj.cmds, obj.cmdNames, obj.key,msg]=obj.Key.convert();
        bKeyChange=obj.Key.bKeyChange;
        if ~isempty(msg)
            obj.append_msg(msg);
        end
        if ~isempty(obj.Key.literal)
            obj.append_bUp('key');
        end
        if exitflag
            return
        end

        % STRING
        [obj.str,obj.pos,obj.strMode,obj.strFlag,bDiff]=obj.Key.getString(); % HERE
        if bDiff
            obj.append_bUp('str');
        end

        % CMDS
        exitflag=~obj.parse_cmds(false);
    end
    function clc(obj)
        if strcmp(obj.Key.aKeyStr,'SHELL')
            obj.Hist.cmd.bView=false(obj.nHistory,1);
        end
    end
    function ret(obj)
        aKey=obj.Key.aKeyStr;
        if strcmp(aKey,'SHELL')
            obj.eval();
            obj.Parent.append_reset('cmd','cmdText');
            obj.Parent.reloop();
        elseif isfield(obj.strDest,aKey)
            % XXX return param name
            dest=obj.strDest.(aKey);
            if ~iscell(dest)
                dest={dest};
            end
            if ~iscell(dest{1})
                dest={dest};
            end
            for i = 1:length(dest)
                if ~ismember(dest{i}{1},{'str','cmd','key'})
                    str=obj.Key.returnString(aKey);
                    d=dest{i}{1};
                    if length(dest{i}) > 1
                        args=dest{i}(2:end);
                    else
                        args={};
                    end
                    out=obj.Parent.pass_string(str,d,args);
                end
            end
            obj.Parent.lastMode;
        end
    end
    function [exitflag]=eval(obj,str,bAppend)
        obj.msg='';
        exitflag=false;
        obj.append_bUp('str');

        if nargin < 2
            str=obj.Key.returnString('SHELL');
        end
        if nargin < 3 || isempty(bAppend)
            bAppend=true;
        end

        if isempty(str)
            return
        end
        str=strtrim(str);
        if isempty(str)
            return
        end
        cmds=strsplit(strrep(str,';',';@@@'),'@@@');
        cmds(cellfun(@isempty,cmds))=[];

        CMD=cell(length(cmds),1);
        types=zeros(length(cmds),1);
        for i = 1:length(cmds)
            cmd=cmds{i};
            c=str(1);
            exitflag=false;
            switch c
                case {'.','@'}
                    [CMD{i},exitflag]=obj.parse_parent_str(cmd(2:end));
                    cmds{i}=cmds{i}(2:end);
                    types(i)='p';
                case '>'
                    CMD{i}=cmd(2:end);
                    cmds{i}=cmds{i}(2:end);
                    types(i)='m';
                case {'$','!'}
                    CMD{i}=cmd(2:end);
                    cmds{i}=cmds{i}(2:end);
                    types(i)='u';
                otherwise
                    [CMD{i},exitflag]=obj.parse_ex_str(cmd);
                    types(i)='e';
            end
            if exitflag
                obj.append_history(true,types(1),str,'',false);
                return
            end
        end

        obj.cmds=CMD;
        exitflag=~obj.parse_cmds(true,CMD,types,cmds,bAppend);
    end
%% PRIVATE
    function obj=init_update(obj)
        obj.bUp=struct();

        obj.bUp=cell(3,1);
        obj.bUp{1}='key';
        obj.bUp{2}='str';
        obj.bUp{3}='cmd';

        obj.bInit=true;
    end
    function append_bUp(obj,name)
        if ~ismember(obj.bUp,name)
            obj.bUp{end+1,1}=name;
        end
    end
    function init_hist(obj)
        typs = {'key','cmd'};
        flds = {'Cmd','Out','Msg','Typ'};
        %n    = [4    ,1    ,1    ,1    ,1];
        for i = 1:length(typs)
            for j = 1:length(flds)
                obj.Hist.(typs{i}).(flds{j})=cell(obj.nHistory,1);
            end
            obj.Hist.(typs{i}).bView=false(obj.nHistory,1);
        end
    end
    function append_history(obj,bExReturn,typ,cmd,out,bAllMsg);
        if bExReturn
            TYP='cmd';
        else
            TYP='key';
        end
        if bAllMsg
            msg=obj.msg;
        else
            msg=obj.msg{end};
        end
        if bExReturn && isempty(out) && ~isempty(msg)
            if bAllMsg
                obj.msg='';
            else
                obj.msg(end)=[];
            end
            out=msg;
        end
        append_fun(obj,typ,TYP,'Typ');
        append_fun(obj,cmd,TYP,'Cmd');
        append_fun(obj,out,TYP,'Out');
        append_fun(obj,msg,TYP,'Msg');
        append_fun(obj,true,TYP,'bView');

        function append_fun(obj,in,TYP,fld)
            if iscell(in) && size(in,1) > 1
                n=numel(in);
                obj.Hist.(TYP).(fld)(1:n-obj.nHistory,:)=[];
                obj.Hist.(TYP).(fld)(end+n,:)=in;
            else
                obj.Hist.(TYP).(fld)(1,:)=[];
                if (~iscell(obj.Hist.(TYP).(fld)) || iscell(in)) && size(in,2) == size(obj.Hist.(TYP).(fld),2)
                    obj.Hist.(TYP).(fld)(end+1,:)=in;
                else
                    obj.Hist.(TYP).(fld){end+1,:}=in;
                end
            end
        end
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
    function bSuccess=parse_cmds(obj,bExReturn,CMDS,typ,strs,bAppend)
        if nargin < 3
            typ='e';
            CMDS=vertcat(obj.cmds{:});
        end
        while iscell(CMDS{1})
            CMDS=vertcat(CMDS{:});
        end
        if size(CMDS,1) < 1
            bSuccess=false;
            return
        end
        if nargin < 5 || isempty(strs)
            strs=repmat({''},size(CMDS,1),1);
        end
        if nargin < 6 || isempty(bAppend)
            bAppend=true;
        end

        obj.msgInit=true;
        exitflag=false;
        N=size(CMDS,1);
        for i = 1:N
            switch typ
                case {'e','p'}
                    [exitflag,out]=obj.eval_ex(CMDS(i,:),bExReturn);
                    act=obj.cmdNames;
                case 'm'
                    [exitflag,out]=obj.eval_mat(CMDS(i,:),bExReturn);
                    act=CMDS{i,:};
                case 'u'
                    [exitflag,out]=obj.eval_unix(CMDS(i,:),bExReturn);
                    act=CMDS{i,:};
                otherwise
                    error(['Invalid shell type ' typ ]);
            end
            if bExReturn
                if iscell(strs) && ~isempty(strs)
                    if length(strs) >= i
                        cmd=strs{i};
                    elseif length(strs)==1
                        cmd=strs{1};
                    end
                else
                    cmd=strs;
                end
            else
                cmd=act;
            end
            if bAppend && (~bExReturn || (bExReturn && i==1))
                obj.append_history(bExReturn,typ,cmd,out,true);
            end
            if exitflag
                break
            end
        end
        bSuccess=~exitflag;
        obj.nCmds=i;

    end
    function [exitflag,out]=eval_mat(obj,cmd,~)
        exitflag=false;
        str=['evalin(''base'',''' cmd{1} ''')'];
        bRmHtml=true; % TODO
        try
            if bRmHtml
                out=regexprep(evalc(str),'<.*?>','');
            else
             out=evalc(str);
            end
        catch me
            n=length(dbstack());
            stack=me.stack;
            stack(1:n)=[];
            cause=me.cause;

            % TODO stack?

            ME=MException(me.identifier,me.message);
            if ~isempty(cause)
                ME.addCause(cause);
            end

            exitflag=true;
            obj.append_msg(ME.message);
            out=ME.getReport('basic','hyperlinks','off');
            %fprintf(fid,'%sin %s at %i\n',txt,ME.stack(e).name,ME.stack(e).line);
        end
    end
    function [exitflag,out]=eval_unix(obj,cmd,~)
        if isunix
            [status,out]=unix(cmd);
            out=out(1:end-1);
        elseif ispc
            [status,out]=system(cmd);
        end
        exitflag=status > 0;
        if exitflag
            obj.append_msg(out);
            out='';
        end
    end
    function [exitflag,out]=eval_ex(obj,CMD,bExReturn)
        exitflag=false;
        out='';
        [dest,cmd,det]=obj.split_cmd(CMD);

        switch dest
        case 'key'
            % ~bExReturn evaluated in Key
            if bExReturn
                obj.Key.read_meta({cmd,det{:}});
            end
        case 'str'
            % ~bExReturn evaluated in Key
            if bExReturn
                obj.Key.KeyStr.(cmd)(det{:});
            end
        case 'cmd'
            if strcmp(cmd,'eval')
                [exitflag]=obj.eval(obj.Key.returnString('SHELL'),true);
            elseif ismethod('PsyShell',cmd)
                obj.(cmd)(det{:});
            else
                obj.append_msg(['No such command ' cmd ' for Cmd']);
                exitflag=true;
            end
        otherwise %% PARENT & OTHER
            [exitflag,out]=obj.run_cmd(dest,cmd,det);
        end

        %% UPDATE
        if ~exitflag
            obj.append_bUp(dest);
        end
    end
    function [dest,CMD,det]=split_cmd(obj,cmd)
        dest=cmd{1};
        CMD=cmd{2};
        if length(cmd) >= 3
            det=cmd(3:end);
        else
            det={};
        end
        det(cellfun(@isempty,det))=[];
        if isempty(det)
            return
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
            str=obj.getString(); % HERE
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
    function [exitflag,out]=run_cmd(obj,dest,cmd,det)
        m=[];
        out='';
        exitflag=false;

        if ~iscell(dest) && strcmp(dest,'Parent')
            D=obj.Parent;
        else
            try
                if iscell(dest)
                    d=strjoin(dest,'.');
                    D=getfield(obj,'Parent',dest{:});
                else
                    d=dest;
                    D=obj.Parent.(dest);
                end
            catch ME
                if strcmp(ME.identifier,'MATLAB:noSuchMethodOrField')
                    exitflag=true;
                    m=(['Invalid command ' cmd ' to ' d ]);
                    obj.append_msg(m);
                    return
                end
            end
        end

        if strcmp(cmd,'set')
            obj.set_fun(D,det{:});
        elseif strcmp(cmd,'toggle')
            obj.toggle_fun(D,det{:});
        else
            n=nargout(@() D.(cmd));
            try
                [vargs{1:n}]=D.(cmd)(det{:});
                if n == 1 && Num.isBinary(vargs{1})
                    exitflag=vargs{1};
                elseif n == 1 && ischar(vargs{1})
                    m=vargs{1};
                elseif n>1
                    exitflag=vargs{1};
                    m=vargs{2};
                    if n == 3
                        out=vargs{3};
                    elseif n > 3
                        out=vargs(3:end);
                    end
                end
            catch ME
                m=ME.message;
                exitflag=true;
            end
            %m=(['Invalid command ' cmd ' to ' dest ]);
            %exitflag=true;
        end
        if ~isempty(m)
            obj.append_msg(m);
        end
    end
%% HANDLE EX
    function [cmd,exitflag]=parse_parent_str(obj,str);
        cmd='';
        exitflag=false;
        spl=strsplit(str,' ');
        spl(cellfun(@isempty,spl))=[];
        if isempty(spl)
            exitflag=true;
            return
        end
        first=strsplit(spl{1},'.');
        if numel(first)==1
            e=first{1};
        else
            e=first{end};
        end
        first(end)=[];

        dest='';
        cmd='';
        prop='';
        if ismethod(obj.Parent,e)
            cmd=e;
        elseif isprop(obj.Parent,e)
            prop=e;
        else
            dest=e;
        end

        if ~isempty(first)
            dest={'Parent' first{1:end} dest};
        elseif ~isempty(dest)
            dest={'Parent' dest};
        else
            dest='Parent';
        end

        if ~isempty(cmd)
            s=2;
        elseif length(spl) > 1
            cmd=spl{2};
            s=3;
        else
            obj.append_msg(['Not a valid Parent command: ' str]);
            exitflag=true;
            return
        end

        if length(spl) > 1
            if strcmp(cmd,'toggle')
                prop=spl{s};
                args=spl(s+1:end);
            elseif strcmp(cmd,'set')
                prop=spl{s};
                args=spl(s+1);
            else
                args=spl(s:end);
            end
        else
            args={};
        end
        if ~isempty(prop)
            cmd={dest,cmd,prop,args};
        else
            cmd={dest,cmd,args,''};
        end
    end
    function [cmd,exitflag]=parse_ex_str(obj,str)
        % NOTE PARSING EX/Alias CMD NOT LONG COMMAND
        cmd='';
        exitflag=false;
        spl=strsplit(str,' ');
        spl(cellfun(@isempty,spl))=[];
        if isempty(spl)
            exitflag=true;
            return
        end

        if numel(spl)>1 && numel(spl{1})==1
            excmd=strjoin(spl(1:2),' ');
            s=3;
        else
            excmd=spl{1};
            s=2;
        end
        if numel(spl) >= s
            args=spl(s:end);
        else
            args={};
        end

        if ~ismember(excmd,obj.Key.KeyDef.ex)
            obj.append_msg(['Not a valid command: ' excmd]);
            exitflag=true;
            return
        end
        cmd=obj.Key.KeyDef.ex2cmd(excmd);
        if ~isempty(args)
            cmd=obj.parse_meta_args(cmd,args);
        end
    end
    function set_fun(obj,D,prp,det)
        if iscell(det) && numel(det)==1
            det=det{1};
        end
        obj.set_dest_fun(D,prp,det);
    end
    function toggle_fun(obj,D,prp,vals)
        val=D.(prp);
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
        obj.set_dest_fun(D,prp,new);
    end
    function set_dest_fun(obj,D,prp,val)
        if ischar(val) && startsWith(val,'@')
            val=eval([ 'obj.Parent.' val(2:end) ';']);
        end
        D.(prp)=val;
    end

end
end
