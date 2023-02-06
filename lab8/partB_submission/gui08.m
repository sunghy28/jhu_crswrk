function gui08
	% Comment out the next line, then uncomment the lines
	% related to your OS
	%error('You must edit this file first!');

	% Use this line for Windows
	% Edit 'COM3' to match your port
	% (use device manager to check the port name)
%	h.port=serial('COM3');

	% Use this line for Linux
	% Edit '/dev/ttyUSB0' to match your port
	% (use "ls /dev/ttyUSB*" to list the serial ports)
	% (also use "chmod 777 /dev/ttyUSB*" as root to enable access)
	h.port=serial('/dev/ttyUSB0');

	% Use this line for Mac OS X
	% Edit '/dev/tty.usbserial-A1UTV1C' to match your port
	% (use "ls /dev/tty.usbserial*" to list the serial ports)
	% (also use "sudo chmod 777 /dev/tty.usbserial*" to enable access)
%	h.port=serial('/dev/tty.usbserial-A1UTV1C');

	% Set serial port BAUD rate and open it
	set(h.port,'BaudRate',921600);
	fopen(h.port);

	% Initialize UIControls
	h.loadbit=0;
	h.closefig=0;
	h.fig=figure('Position',[300 300 475 200]);% X Y W H
	set(h.fig,'CloseRequestFcn',@closefig);

	h.filename=uicontrol('Style','edit',...
		'String','Select bit file...',...
		'Units','pixels',...
		'Position',[50 150 275 25],...
		'FontUnits','pixels',...
		'FontSize',20);
	h.browsebut=uicontrol('Style','pushbutton',...
		'String','Browse',...
		'Units','pixels',...
		'Position',[325 150 100 25],...
		'FontUnits','pixels',...
		'FontSize',20,...
		'Callback',@browsebut);
	h.data_out=uicontrol('Style','edit',...
		'String','0',...
		'Units','pixels',...
		'Position',[50 75 375 25],...
		'FontUnits','pixels',...
		'FontSize',20);
	h.data_in=uicontrol('Style','text',...
		'String','0',...
		'Units','pixels',...
		'Position',[50 25 375 25],...
		'FontUnits','pixels',...
		'FontSize',20);

	% Set units to normalized to make the window extensible
	set(h.browsebut,'Units','normalized');
	set(h.browsebut,'FontUnits','normalized');
	set(h.filename,'Units','normalized');
	set(h.filename,'FontUnits','normalized');
	set(h.data_out,'Units','normalized');
	set(h.data_out,'FontUnits','normalized');
	set(h.data_in,'Units','normalized');
	set(h.data_in,'FontUnits','normalized');

	% Main loop
	h.error='';
	while true
		% Check for a close figure request
		if (h.closefig==1)
			break;
		end
		% Check for a bit file load request
		if (h.loadbit==1)
			h.loadbit=0;
			[FileName,PathName]=uigetfile('*.bit','Select the FPGA bit file');
			if (FileName==0)
				continue;
			end
			if (PathName==0)
				h.filename.String=FileName;
			else
				h.filename.String=strcat(PathName,FileName);
			end
			% Read data from file
			fid=fopen(h.filename.String,'r');
			data=fread(fid,inf,'uint8');
			fclose(fid);
			% Skip header
			if (isequal(data(1:13),[0 9 15 240 15 240 15 240 15 240 0 0 1]')~=1)
				warning('Unexpected bit file header.');
				continue;
			end
			data=data(14:end);
			while (data(1)=='a')||(data(1)=='b')||(data(1)=='c')||(data(1)=='d')
				l=data(2)*256+data(3);
				data=data(l+4:end);
			end
			if (data(1)=='e')
				data=data(6:end);
			else
				warning('Unexpected header key.');
				continue;
			end

			% Send begin command
			fwrite(h.port,'[');

			% Get status
			r=abs(fread(h.port,1));
			if (isempty(r)==1)
				h.error='Timeout reading from FPGA board.';
				break;
			elseif (r=='E')
				h.error='FPGA reset failed.';
				break;
			elseif (r~='@')
				h.error='Unexpected return status.';
				break;
			end

			% Make command array
			cmd=92*ones(2,numel(data));
			cmd(2,:)=data;
			cmd=char(cmd(:))';

			% Send program data in OutputBufferSize chunks
			b=get(h.port,'OutputBufferSize');
			h.closewait=0;
			h.wait=waitbar(0,'Programming FPGA...');
			set(h.wait,'CloseRequestFcn',@closewait);
			for p=1:b:length(cmd)
				if (p+b-1>length(cmd))
					fwrite(h.port,cmd(p:length(cmd)));
				else
					fwrite(h.port,cmd(p:p+b-1));
				end
				waitbar((p+b-1)/length(cmd),h.wait);
				if (h.closewait==1)||(h.closefig==1)
					break;
				end
			end
			if (h.closewait==1)||(h.closefig==1)
				close(h.wait);
				delete(h.wait);
				h.error='Bit file loading aborted.';
				break;
			end
			close(h.wait);
			delete(h.wait);

			% Send end command
			fwrite(h.port,']');

			% Check return status
			r=abs(fread(h.port,1));
			if (isempty(r)==1)
				h.error='Timeout reading from FPGA board.';
				break;
			elseif (r=='E')
				h.error='FPGA programming failed.';
				break;
			elseif (r~='@')
				h.error='Unexpected return status.';
				break;
			end
		end

		% Convert data from display
		data_out=sscanf(get(h.data_out,'string'),'%g');
		if (isempty(data_out)==1)
			data_out=0;
		end
		data_out=round(data_out);
		if (data_out<0)
			data_out=0;
		end
		if (data_out>24000000)
			data_out=24000000;
		end
		set(h.data_out,'String',sprintf('%.0f',data_out));

		% Split data into nibbles
		nib=rem(floor(data_out./(10.^(0:7))),10);

		% Write four bytes to FPGA
		tmp=zeros(1,4);
		tmp(4)=nib(8)*16+nib(7);
		tmp(3)=nib(6)*16+nib(5);
		tmp(2)=nib(4)*16+nib(3);
		tmp(1)=nib(2)*16+nib(1);
		fwrite(h.port,[94 92 tmp(1) 92 tmp(2) 92 tmp(3) 92 tmp(4)]);

		% Read two bytes from FPGA
		fwrite(h.port,[94 95 95]);
		tmp=abs(fread(h.port,2));
		if (length(tmp)~=2)
			h.error='Timeout reading from FPGA board.';
			break;
		end

		% Split data into nibbles
		nib(1)=floor(tmp(2)/16);
		nib(2)=mod(tmp(2),16);
		nib(3)=floor(tmp(1)/16);

		% Convert data for display
		switch mod(tmp(1),16)
			case 0
				data_in=sprintf('%X.%X%X Hz',nib(1),nib(2),nib(3));
			case 1
				data_in=sprintf('%X%X.%X Hz',nib(1),nib(2),nib(3));
			case 2
				data_in=sprintf('%X%X%X. Hz',nib(1),nib(2),nib(3));
			case 3
				data_in=sprintf('%X.%X%X kHz',nib(1),nib(2),nib(3));
			case 4
				data_in=sprintf('%X%X.%X kHz',nib(1),nib(2),nib(3));
			case 5
				data_in=sprintf('%X%X%X. kHz',nib(1),nib(2),nib(3));
			case 6
				data_in=sprintf('%X.%X%X MHz',nib(1),nib(2),nib(3));
			case 7
				data_in=sprintf('%X%X.%X MHz',nib(1),nib(2),nib(3));
			case 8
				data_in=sprintf('%X%X%X. MHz',nib(1),nib(2),nib(3));
			case 9
				data_in=sprintf('%X.%X%X GHz',nib(1),nib(2),nib(3));
			case 10
				data_in=sprintf('%X%X.%X GHz',nib(1),nib(2),nib(3));
			case 11
				data_in=sprintf('%X%X%X. GHz',nib(1),nib(2),nib(3));
			case 12
				data_in=sprintf('%X.%X%X THz',nib(1),nib(2),nib(3));
			case 13
				data_in=sprintf('%X%X.%X THz',nib(1),nib(2),nib(3));
			case 14
				data_in=sprintf('%X%X%X. THz',nib(1),nib(2),nib(3));
			case 15
				data_in='OVER';
			otherwise
				data_in='ERROR';
		end
		set(h.data_in,'String',data_in);
		drawnow;
	end
	fclose(h.port);
	delete(h.port);
	delete(h.fig);
	if (~isempty(h.error))
		error(h.error);
	end

	% Callbacks
	function closewait(~,~)
		h.closewait=1;
	end
	function closefig(~,~)
		h.closefig=1;
	end
	function browsebut(~,~,~)
		h.loadbit=1;
	end
end
