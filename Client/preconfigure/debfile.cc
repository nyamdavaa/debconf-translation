#include <stdio.h>
#include <apt-pkg/tagfile.h>
#include <extracttar.h>
#include <arfile.h>

#include <apt-pkg/pkgcache.h>
#include "debfile.h"

DebFile::DebFile(string debfile)
	: File(debfile, FileFd::ReadOnly), Control(0), PreDepOp(0), Config(0), Template(0), Which(None)
{
}

DebFile::~DebFile()
{
	delete [] Control;
	delete [] Config;
	delete [] Template;
}

bool DebFile::Go()
{
	ARArchive AR(File);
	const ARArchive::Member *Member = AR.FindMember("control.tar.gz");
	if (Member == 0)
	{
		fprintf(stderr, "This is not a valid DEB archive.\n");
		return false;
	}
	
	if (File.Seek(Member->Start) == false)
	{
		return false;
	}

	ExtractTar Tar(File, Member->Size);
	return Tar.Go(*this);
}

bool DebFile::DoItem(Item &I, int &Fd)
{
	if (strcmp(I.Name, "control") == 0)
	{
		delete [] Control;
		Control = new char[I.Size+1];
		Control[I.Size] = 0;
		Which = IsControl;
		ControlLen = I.Size;
		// make it call the Process method below. this is so evil
		Fd = -2;
	}
	else if (strcmp(I.Name, "config") == 0)
	{
		delete [] Config;
		Config = new char[I.Size+1];
		Config[I.Size] = 0;
		Which = IsConfig;
		Fd = -2; 
	} 
	else if (strcmp(I.Name, "templates") == 0)
	{
		delete [] Template;
		Template = new char[I.Size+1];
		Template[I.Size] = 0;
		Which = IsTemplate;
		Fd = -2;
	} 
	else 
	{
		Fd = -1;
	}
	return true;
}

bool DebFile::Process(Item &I, const unsigned char *data, 
		unsigned long size, unsigned long pos)
{
	switch (Which)
	{
	case IsControl:
		memcpy(Control + pos, data, size);
		break;
	case IsConfig:
		memcpy(Config + pos, data, size);
		break;
	case IsTemplate:
		memcpy(Template + pos, data, size);
		break;
	default: /* throw it away */ ;
	}
	return true;
}

bool DebFile::ParseInfo()
{
	if (Control == NULL) return false;
	pkgTagSection Section;
	Section.Scan(Control, ControlLen);

	Package = Section.FindS("Package");
	Version = Section.FindS("Version");
	
	const char *Start, *Stop;
	if (Section.Find("Pre-Depends", Start, Stop) == true)
	{
		while (1)
		{
			string P, V;
			unsigned int Op;
			Start = ParseDepends(Start, Stop, P, V, Op);
			if (Start == 0) return false;
			if (P == "debconf")
			{
				PreDepVer = V;
				PreDepOp = Op;
				break;
			}
			if (Start == Stop) break;
		}
	}
	
	return true;
}


const char *DebFile::ParseDepends(const char *Start,const char *Stop,
				string &Package,string &Ver,
				unsigned int &Op)
{
   // Strip off leading space
   for (;Start != Stop && isspace(*Start) != 0; Start++);
   
   // Parse off the package name
   const char *I = Start;
   for (;I != Stop && isspace(*I) == 0 && *I != '(' && *I != ')' &&
	*I != ',' && *I != '|'; I++);
   
   // Malformed, no '('
   if (I != Stop && *I == ')')
      return 0;

   if (I == Start)
      return 0;
   
   // Stash the package name
   Package.assign(Start,I - Start);
   
   // Skip white space to the '('
   for (;I != Stop && isspace(*I) != 0 ; I++);
   
   // Parse a version
   if (I != Stop && *I == '(')
   {
      // Skip the '('
      for (I++; I != Stop && isspace(*I) != 0 ; I++);
      if (I + 3 >= Stop)
	 return 0;
      
      // Determine the operator
      switch (*I)
      {
	 case '<':
	 I++;
	 if (*I == '=')
	 {
	    I++;
	    Op = pkgCache::Dep::LessEq;
	    break;
	 }
	 
	 if (*I == '<')
	 {
	    I++;
	    Op = pkgCache::Dep::Less;
	    break;
	 }
	 
	 // < is the same as <= and << is really Cs < for some reason
	 Op = pkgCache::Dep::LessEq;
	 break;
	 
	 case '>':
	 I++;
	 if (*I == '=')
	 {
	    I++;
	    Op = pkgCache::Dep::GreaterEq;
	    break;
	 }
	 
	 if (*I == '>')
	 {
	    I++;
	    Op = pkgCache::Dep::Greater;
	    break;
	 }
	 
	 // > is the same as >= and >> is really Cs > for some reason
	 Op = pkgCache::Dep::GreaterEq;
	 break;
	 
	 case '=':
	 Op = pkgCache::Dep::Equals;
	 I++;
	 break;
	 
	 // HACK around bad package definitions
	 default:
	 Op = pkgCache::Dep::Equals;
	 break;
      }
      
      // Skip whitespace
      for (;I != Stop && isspace(*I) != 0; I++);
      Start = I;
      for (;I != Stop && *I != ')'; I++);
      if (I == Stop || Start == I)
	 return 0;     
      
      // Skip trailing whitespace
      const char *End = I;
      for (; End > Start && isspace(End[-1]); End--);
      
      Ver = string(Start,End-Start);
      I++;
   }
   else
   {
      Ver = string();
      Op = pkgCache::Dep::NoOp;
   }
   
   // Skip whitespace
   for (;I != Stop && isspace(*I) != 0; I++);

   if (I != Stop && *I == '|')
      Op |= pkgCache::Dep::Or;
   
   if (I == Stop || *I == ',' || *I == '|')
   {
      if (I != Stop)
	 for (I++; I != Stop && isspace(*I) != 0; I++);
      return I;
   }
   
   return 0;
}