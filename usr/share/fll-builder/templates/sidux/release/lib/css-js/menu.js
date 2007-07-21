/********************************************
Show hide / DropMenu functions
********************************************/
if ( !document.layers )
{
	dom = ( document.getElementById ) ? document.getElementById : false;
}
// initialize variables
var count_div_ids = 30;// this is max number of ids for menus
var menuID = 'sm';

/*
Main showHide control function, needs the item id and number, like dropMenu + 2
these will be either conctatenated or used directly for other functions called
*/
function showHide( menuNumber )
{
	if ( dom )
	{
		full_ID = menuID + menuNumber;
		hideAll();
		showElement ( full_ID );
	}
}
/*
Toggles the element visibility/display to visible/block 
*/
function showElement( full_ID ) { 
	if ( dom ) 
	{ 
		if ( document.getElementById( full_ID )	)// test to make sure element id exists
		{
			document.getElementById( full_ID ).style.display="block"; 
		} 
	}
} 

/* 
The hideElement function is almost identical to the showElement function in it’s working, 
except that it changes the visibility/display property to hidden/none. 
*/
function hideElement( full_item_id ) { 
	if ( dom ) 
	{ 
		if ( document.getElementById( full_item_id )	)// test to make sure element id exists
		{
			document.getElementById( full_item_id ).style.display="none"; 
		}
	} 
} 

/* 
This function allows us to hide every element used the menu system at one time. This means 
that we can make sure that all elements are turned off, before making the appropriate element 
visible. All you need to do is call the hideElement function for each element used in your 
menu system. 
*/
function hideAll() 
{ 
	if ( dom ) 
	{ 
		for (i = 0; i < count_div_ids ; i++)
		{
			full_item_id = menuID + i;
			if ( document.getElementById( full_item_id )	)// test to make sure element id exists
			{
				hideElement( full_item_id );
			}
		}
	}
} 

/* this gets around some xhmlt validation issues, handles case that should be handled
by <noscript>, but I'm just turning it around and scripting in the script, and letting
the default css be the noscript value */
function noscript_css()
{
	document.write ( '<style type="text/css">ul li:hover ul {display:none;}</style>' );
}
