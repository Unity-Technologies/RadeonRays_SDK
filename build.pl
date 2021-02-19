#!/usr/bin/env perl -w
use Cwd qw(getcwd);
use File::Path;

my $pathToLib;
BEGIN { $pathToLib = getcwd . '/3rdparty/Perl/lib' }
use lib $pathToLib;
use File::Copy::Recursive qw(fcopy dircopy);
use Config;
use Archive::Zip;
use SDKDownloader;

my $buildCommandPrefix = '';
sub CheckInstallSDK
{
    print 'Setting up the Linux SDK';
    SDKDownloader::PrepareSDK('linux-sdk', '20180928', "artifacts");
    $buildCommandPrefix = "schroot -c $ENV{LINUX_BUILD_ENVIRONMENT} --";
}

my $err; # used by CheckFileError

my $mac_x64 = "cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES=x86_64 -DCMAKE_OSX_DEPLOYMENT_TARGET=10.12 -DRR_USE_EMBREE=OFF -DRR_USE_OPENCL=ON -DRR_EMBED_KERNELS=OFF -DRR_SAFE_MATH=ON -DRR_SHARED_CALC=OFF";
my $mac_arm64 = "cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 -DRR_USE_EMBREE=OFF -DRR_USE_OPENCL=ON -DRR_EMBED_KERNELS=OFF -DRR_SAFE_MATH=ON -DRR_SHARED_CALC=OFF";
my $linuxD = "cmake -DCMAKE_BUILD_TYPE=Debug -DRR_USE_EMBREE=OFF -DRR_USE_OPENCL=ON -DRR_EMBED_KERNELS=OFF -DRR_SAFE_MATH=ON -DRR_SHARED_CALC=OFF -DRR_USE_VULKAN=OFF";
my $linuxR = "cmake -DCMAKE_BUILD_TYPE=Release -DRR_USE_EMBREE=OFF -DRR_USE_OPENCL=ON -DRR_EMBED_KERNELS=OFF -DRR_SAFE_MATH=ON -DRR_SHARED_CALC=OFF -DRR_USE_VULKAN=OFF";
my $windows = "cmake -G \"Visual Studio 14 2015 Win64\" -DRR_USE_EMBREE=OFF -DRR_USE_OPENCL=ON -DRR_EMBED_KERNELS=ON -DRR_SAFE_MATH=ON -DRR_SHARED_CALC=ON -DCMAKE_PREFIX_PATH=3rdparty/opencl";

sub BuildRadeonRays
{
	my $cmakeString = shift;
    system("$buildCommandPrefix $cmakeString") && die("cmake failed");
	if ($Config{osname} eq "MSWin32")
	{
		system("\"C:/Program Files (x86)/Microsoft Visual Studio 14.0/Common7/IDE/devenv.exe\" RadeonRaysSDK.sln /Build Debug");
		system("\"C:/Program Files (x86)/Microsoft Visual Studio 14.0/Common7/IDE/devenv.exe\" RadeonRaysSDK.sln /Build RelWithDebInfo");
	}
	elsif ($Config{osname} eq "darwin")
	{
		system("make clean") && die("Failed make clean");
		system("$buildCommandPrefix make") && die("Failed make");
	}
	else
	{
		system("$buildCommandPrefix make") && die("Failed make");
	}
}

sub CopyHeaders
{
	mkpath('artifacts/include', {error => \ $err} );
	CheckFileError();
	dircopy("RadeonRays/include", "artifacts/include") or die("Failed to copy RadeonRays headers.");
	dircopy("Calc/inc", "artifacts/include") or die("Failed to copy Calc headers.");
}

sub CheckFileError
{
	if (@$err) 
	{
		for my $diag (@$err) 
		{
			my ($file, $message) = %$diag;
			if ($file eq '') 
			{
			  die("general error: $message\n");
			}
			else 
			{
			  die("problem unlinking $file: $message\n");
			}
		}
	}
}


mkpath('artifacts', {error => \ $err} );
CheckFileError();
mkpath('artifacts/lib', {error => \ $err} );
CheckFileError();
mkpath('builds', {error => \ $err} );
CheckFileError();

if ($Config{osname} eq "darwin")
{
	if (system("cmake -version"))
	{
		system("brew install cmake") && die("Failed to install cmake");
	}

	BuildRadeonRays($mac_x64);
	mkpath('artifacts/lib/macOS/x64', {error => \ $err} );
	CheckFileError();
	fcopy("bin/x86_64/libRadeonRays.dylib", "artifacts/lib/macOS/x64/libRadeonRays.dylib") or die "Copy of libRadeonRays.dylib failed: $!";

	BuildRadeonRays($mac_arm64);
	mkpath('artifacts/lib/macOS/arm64', {error => \ $err} );
	CheckFileError();
	fcopy("bin/arm64/libRadeonRays.dylib", "artifacts/lib/macOS/arm64/libRadeonRays.dylib") or die "Copy of libRadeonRays.dylib failed: $!";
}

if ($Config{osname} eq "linux")
{
	CheckInstallSDK();
	mkpath('artifacts/bin', {error => \ $err} );
	CheckFileError();
	mkpath('artifacts/bin/Linux', {error => \ $err} );
	CheckFileError();
	
	BuildRadeonRays($linuxD);
	#fcopy("bin/libCalcD.so", "artifacts/bin/Linux/libCalc.so") or die "Copy of libCalc.so failed: $!";
	fcopy("bin/libRadeonRaysD.so", "artifacts/bin/Linux/libRadeonRaysD.so") or die "Copy of libRadeonRaysD.so failed: $!";
	fcopy("bin/libRadeonRaysD.so.2.0", "artifacts/bin/Linux/libRadeonRaysD.so.2.0") or die "Copy of libRadeonRaysD.so.2.0 failed: $!";
	
	BuildRadeonRays($linuxR);
	#fcopy("bin/libCalc.so", "artifacts/bin/Linux/libCalc.so") or die "Copy of libCalc.so failed: $!";
	fcopy("bin/libRadeonRays.so", "artifacts/bin/Linux/libRadeonRays.so") or die "Copy of libRadeonRays.so failed: $!";
	fcopy("bin/libRadeonRays.so.2.0", "artifacts/bin/Linux/libRadeonRays.so.2.0") or die "Copy of libRadeonRays.so.2.0 failed: $!";
	
	system("rm -r artifacts/SDKDownloader") && die("Unable to clean up SDKDownloader directory.");
}

if ($Config{osname} eq "MSWin32")
{
	BuildRadeonRays($windows);
	
	# copy dll files
	mkpath('artifacts/bin', {error => \ $err} );
	CheckFileError();
	mkpath('artifacts/bin/Windows', {error => \ $err} );
	CheckFileError();
	
	# Release
	fcopy("bin/RelWithDebInfo/Calc.dll", "artifacts/bin/Windows/Calc.dll") or die "Copy of Calc.dll failed: $!";
	fcopy("bin/RelWithDebInfo/Calc.pdb", "artifacts/bin/Windows/Calc.pdb") or die "Copy of Calc.pdb failed: $!";
	fcopy("bin/RelWithDebInfo/RadeonRays.dll", "artifacts/bin/Windows/RadeonRays.dll") or die "Copy of RadeonRays.dll failed: $!";
	fcopy("bin/RelWithDebInfo/RadeonRays.pdb", "artifacts/bin/Windows/RadeonRays.pdb") or die "Copy of RadeonRays.pdb failed: $!";
	
	# Debug
	fcopy("bin/Debug/CalcD.dll", "artifacts/bin/Windows/CalcD.dll") or die "Copy of CalcD.dll failed: $!";
	fcopy("bin/Debug/CalcD.pdb", "artifacts/bin/Windows/CalcD.pdb") or die "Copy of CalcD.pdb failed: $!";
	fcopy("bin/Debug/RadeonRaysD.dll", "artifacts/bin/Windows/RadeonRaysD.dll") or die "Copy of RadeonRaysD.dll failed: $!";
	fcopy("bin/Debug/RadeonRaysD.pdb", "artifacts/bin/Windows/RadeonRaysD.pdb") or die "Copy of RadeonRaysD.pdb failed: $!";
	
	# write build version.txt, only needed once as ACompleteBuild will combine all artifacts.
	my $branch = qx("git symbolic-ref -q HEAD");
	my $revision = qx("git rev-parse HEAD");
	open(BUILD_INFO_FILE, '>', "artifacts/version.txt") or die("Unable to write build information to version.txt");
	print BUILD_INFO_FILE "$branch";
	print BUILD_INFO_FILE "$revision";
	close(BUILD_INFO_FILE);
}

CopyHeaders();